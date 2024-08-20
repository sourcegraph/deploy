#!/usr/bin/bash
###############################################################################
# This script is run when the instance is first deployed from the AMI,
# and on every reboot.
# Logs:
#   cron logs in /var/spool/mail/ec2-user
#   script logs in $LOG_FILE
###############################################################################

# Variables
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
AMI_ROOT_VOLUME_VERSION_FILE="/home/$INSTANCE_USERNAME/.sourcegraph-version"
AMI_VERSION="$(cat $AMI_ROOT_VOLUME_VERSION_FILE)"
CUSTOMER_OVERRIDE_FILE='/mnt/data/override.yaml'
DATA_VOLUME_VERSION_FILE='/mnt/data/.sourcegraph-version'
DATA_VOLUME_VERSION=""
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
LOCAL_BIN_PATH='/usr/local/bin'
LOG_FILE="/var/log/reboot.sh.log"
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'

# Reusable commands to maintain consistency for the commands this script runs multiple times
HELM_CMD="$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE"
HELM_UPGRADE_INSTALL_CMD="$HELM_CMD upgrade --install --version $AMI_VERSION --values $DEPLOY_PATH/override.yaml"
KUBECTL_CMD="$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE"
KUBECTL_DELETE_PODS_ALL_CMD="$LOCAL_BIN_PATH/kubectl delete pods --all"
RESTART_K3S_CMD="sudo systemctl restart k3s"

# Configure script to output to both console and file
exec > >(sudo tee -a "$LOG_FILE") 2>&1

# Define log function for consistent output format
function log() {
    echo "$(date '+%Y-%m-%d - %H:%M:%S') - $0 - $1"
}

log "Script starting"
START_TIME=$(date +%s)

# If the customer has created an override file on the data volume, then use it
if [ -f $CUSTOMER_OVERRIDE_FILE ]; then
    # Append the customer's override file last, so that values the customer sets override our default values
    log "Found custom Helm values file at $CUSTOMER_OVERRIDE_FILE"
    HELM_UPGRADE_INSTALL_CMD="$HELM_UPGRADE_INSTALL_CMD --values $CUSTOMER_OVERRIDE_FILE"
fi

# If the Sourcegraph version stored on the data volume matches the version stored on the AMI's root volume
# Then this is a regular reboot, not a first time startup or upgrade
if [ -f $DATA_VOLUME_VERSION_FILE ]; then
    DATA_VOLUME_VERSION="$(cat $DATA_VOLUME_VERSION_FILE)"
    if [ -f $CUSTOMER_OVERRIDE_FILE ]; then
        log "Reinstalling Sourcegraph to use the custom Helm values file"
    elif [ "$DATA_VOLUME_VERSION" = "$AMI_VERSION" ]; then
        log "Starting Sourcegraph on version $AMI_VERSION"
        # Recycle pods and restart k3s to clear out any possible startup issues
        log "Recycling pods"
        $KUBECTL_DELETE_PODS_ALL_CMD
        log "Restarting k3s service"
        $RESTART_K3S_CMD
        log "Started Sourcegraph on version $AMI_VERSION"
        # Exit the script early
        exit 0
    elif [[ "$DATA_VOLUME_VERSION" =~ ^.*-base$ ]]; then
        log "Starting Sourcegraph for the first time, on version $AMI_VERSION"
    elif [[ "$DATA_VOLUME_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Upgrading Sourcegraph from $DATA_VOLUME_VERSION to $AMI_VERSION"
    else
        log "Sourcegraph data volume has invalid version '$DATA_VOLUME_VERSION', installing $AMI_VERSION"
    fi
else
    log "Sourcegraph data volume is missing version file at $DATA_VOLUME_VERSION_FILE, installing $AMI_VERSION"
fi

# If k3s is not starting / running successfully, then reset containerd state, so that it becomes ready for the Sourcegraph upgrade
# NOTE: Cluster data is NOT deleted in this process
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    log "k3s service not running, resetting state"
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
    # Enable k3s in this cluster and start the unit now
    sudo systemctl enable --now k3s
else
    # If k3s is running successfully, then delete the existing ingress, to prepare for the upgrade
    log "Deleting ingress"
    $KUBECTL_CMD delete ingress sourcegraph-ingress
fi

# Restart the k3s service after the above changes
log "Restarting k3s service"
$RESTART_K3S_CMD

# Give k3s time to start up
log "Waiting for the k3s service to come up"
sleep 30

# Install or upgrade Sourcegraph and create ingress
cd "$DEPLOY_PATH" || exit 1

# Try to pull the latest Helm chart
# This takes 30+ seconds to timeout if the instance does not have internet connectivity open to our Helm repo
log "Updating Helm chart"
$HELM_CMD repo update

# Apply the Prometheus override
log "Applying Prometheus override"
$KUBECTL_CMD apply -f $DEPLOY_PATH/prometheus-override.ConfigMap.yaml

# If the Sourcegraph Helm charts exist on disk (they always should on a running instance), then use them
# Otherwise, use the Helm charts from the default path
log "Upgrading Sourcegraph"
if [ -f $DEPLOY_PATH/sourcegraph-charts.tgz ]; then
    $HELM_UPGRADE_INSTALL_CMD sourcegraph $DEPLOY_PATH/sourcegraph-charts.tgz
else
    $HELM_UPGRADE_INSTALL_CMD sourcegraph sourcegraph/sourcegraph
fi

# Create the ingress
log "Creating ingress"
$KUBECTL_CMD create -f $DEPLOY_PATH/ingress.yaml

# Give the ingress time to deploy
sleep 5

# If the Executor Helm charts exist on disk, then use them
# Otherwise, use the Helm charts from the default path
log "Upgrading Executors"
if [ -f $DEPLOY_PATH/sourcegraph-executor-k8s-charts.tgz ]; then
    $HELM_UPGRADE_INSTALL_CMD executor $DEPLOY_PATH/sourcegraph-executor-k8s-charts.tgz
else
    $HELM_UPGRADE_INSTALL_CMD executor sourcegraph/sourcegraph-executor-k8s
fi

# Recycle all pods
log "Recycling pods"
$KUBECTL_DELETE_PODS_ALL_CMD

# Give the new pods time to start up
log "Waiting for pods to start up"
sleep 60

# Restart k3s again in case pods are still in crashloopbackoff
# This should not affect a running instance
log "Restarting k3s service"
$RESTART_K3S_CMD

# Write the new version number to both volumes, to pass the version match check on next reboot
HELM_APP_VERSION="$($HELM_CMD history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ':' -f 2 | xargs)"
if [[ "$HELM_APP_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$HELM_APP_VERSION" | sudo tee $AMI_ROOT_VOLUME_VERSION_FILE
    echo "$HELM_APP_VERSION" | sudo tee $DATA_VOLUME_VERSION_FILE
else
    log "Error: Got invalid Sourcegraph app version from Helm history: $HELM_APP_VERSION"
    exit 2
fi

log "Successfully upgraded Sourcegraph to version $HELM_APP_VERSION"
log "Script finishing after $(($(date +%s) - $START_TIME)) seconds"
