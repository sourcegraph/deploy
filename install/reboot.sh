#!/usr/bin/bash
###############################################################################
# This script is run when the instance is first deployed from the AMI,
# and on every reboot.
# Logs:
#   cron logs in /var/spool/mail/ec2-user
#   script logs in $LOG_FILE
###############################################################################

### Variables
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
AMI_ROOT_VOLUME_VERSION_FILE="/home/$INSTANCE_USERNAME/.sourcegraph-version"
AMI_VERSION=""
CUSTOMER_OVERRIDE_FILE='/mnt/data/override.yaml'
DATA_VOLUME_VERSION_FILE='/mnt/data/.sourcegraph-version'
DATA_VOLUME_VERSION=""
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
LOCAL_EXECUTOR_CHARTS_FILE="$DEPLOY_PATH/sourcegraph-executor-k8s-charts.tgz"
LOCAL_SOURCEGRAPH_CHARTS_FILE="$DEPLOY_PATH/sourcegraph-charts.tgz"
HELM_REPO="https://helm.sourcegraph.com/release"
LOCAL_BIN_PATH='/usr/local/bin'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'

### Reusable commands to maintain consistency for the commands this script runs multiple times
HELM_CMD="$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE"
HELM_UPGRADE_INSTALL_CMD="$HELM_CMD upgrade --install --values $DEPLOY_PATH/override.yaml"
KUBECTL_CMD="$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE"
KUBECTL_DELETE_PODS_ALL_CMD="$LOCAL_BIN_PATH/kubectl delete pods --all"
RESTART_K3S_CMD="sudo systemctl restart k3s"


### Logging
# Configure script to output to both console and file
LOG_FILE="/var/log/reboot.sh.log"
exec > >(sudo tee -a "$LOG_FILE") 2>&1

### Functions
# Define log function for consistent output format
function log() {
    echo "$(date '+%Y-%m-%d - %H:%M:%S') - $0 - $1"
}

function recycle_pods_and_restart_k3s() {

    log "Recycling pods"
    $KUBECTL_DELETE_PODS_ALL_CMD

    log "Giving pods time to start up"
    # Could change this to a while [ kubectl get pods | grep -v Running ], with a maximum wait time of 60 seconds, then sleep 5 seconds
    sleep 60

    # Restart k3s in case pods are stuck in a crashloopbackoff
    # This should not affect a running instance
    log "Restarting the k3s service"
    $RESTART_K3S_CMD
}

# Pass the version number when calling this function
function exit_script() {
    sleep 10
    log "Checking pod statuses"
    $KUBECTL_CMD get pods -A
    log "Started Sourcegraph on version $1"
    log "Script finished after $(($(date +%s) - START_TIME)) seconds"
    exit 0
}


### Script execution starts here
log "Script started"
START_TIME=$(date +%s)

### Determine the code path to take
# Get the Sourcegraph version number from the AMI's root volume
# This should be the version of Docker images and Helm charts already baked into the AMI
if [ -f "$AMI_ROOT_VOLUME_VERSION_FILE" ]; then
    AMI_VERSION="$(cat "$AMI_ROOT_VOLUME_VERSION_FILE")"
    HELM_UPGRADE_INSTALL_CMD="$HELM_UPGRADE_INSTALL_CMD --version $AMI_VERSION"
    log "AMI root volume version: $AMI_VERSION"
else
    log "WARNING: Missing AMI root volume version file at $AMI_ROOT_VOLUME_VERSION_FILE"
    # Try to install anyway
fi

# Get the Sourcegraph version number from the attached data volume
# This should be the version of the databases
if [ -f "$DATA_VOLUME_VERSION_FILE" ]; then
    DATA_VOLUME_VERSION="$(cat "$DATA_VOLUME_VERSION_FILE")"
    log "Data volume version: $DATA_VOLUME_VERSION"
else
    log "WARNING: Missing data volume version file at $DATA_VOLUME_VERSION_FILE"
    # Try to install anyway
fi


# If the customer has created an override file on the data volume, then use it, by appending it to the Helm upgrade install command
# Always reinstall Sourcegraph on every boot when there's a custom override.yaml file
# so the customer can apply these changes by rebooting the instance, or running this script
if [ -f "$CUSTOMER_OVERRIDE_FILE" ]; then
    # Append the customer's override file last, so that values the customer sets override our default values
    log "Found custom Helm values file at $CUSTOMER_OVERRIDE_FILE, reinstalling Sourcegraph to use the custom Helm values file, on Sourcegraph version $AMI_VERSION"
    HELM_UPGRADE_INSTALL_CMD="$HELM_UPGRADE_INSTALL_CMD --values $CUSTOMER_OVERRIDE_FILE"

# If the version on the data volume matches the version on the root volume
# And the versions are not empty
# (not performing regex match to avoid different behaviour for non-release builds)
# Then this is a regular reboot
elif [ "$AMI_VERSION" = "$DATA_VOLUME_VERSION" ] && [ -n "$AMI_VERSION" ]; then
    log "Versions match, starting Sourcegraph"
    # Recycle pods and restart k3s to clear out any possible startup issues
    recycle_pods_and_restart_k3s
    # Exit the script early
    exit_script "$AMI_VERSION"

# Otherwise, reinstall Sourcegraph
else
    log "Installing Sourcegraph version $AMI_VERSION"
fi

### Prepare for installation

# If k3s is not starting / running successfully, then reset containerd state, so that it becomes ready for the Sourcegraph upgrade
# NOTE: Cluster data is NOT deleted in this process
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    log "WARNING: k3s service not running, resetting state"
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

# Restart the k3s service after either of the above changes
log "Restarting the k3s service"
$RESTART_K3S_CMD

# Give k3s time to start up
log "Giving the k3s service time to start up"
# Could change this to a while [ ! sudo systemctl status k3s.service | grep -q 'active (running)' ], with a maximum wait time of 30 seconds, then sleep 5 seconds
sleep 30

### Install or upgrade Sourcegraph, and create ingress
log "Changing directory to $DEPLOY_PATH"
cd "$DEPLOY_PATH" || exit 1

# Apply the Prometheus override
log "Applying Prometheus override"
$KUBECTL_CMD apply -f "$DEPLOY_PATH/prometheus-override.ConfigMap.yaml"

# Original script's approach
    # If the Sourcegraph Helm charts exist on disk (they always should on a running instance), then use them
    # Otherwise, use the Helm charts from the Helm repo
# Should we switch this around
    # So that if we have internet connectivity to the Helm repo
    # Then default to use it to get the latest version of the Helm charts for the Sourcegraph release version
    # And if we don't have internet connectivity
    # Then fall back to the local Helm charts on disk?
if [ -f "$LOCAL_SOURCEGRAPH_CHARTS_FILE" ]; then

    log "Upgrading Sourcegraph using Helm charts on disk at $LOCAL_SOURCEGRAPH_CHARTS_FILE"
    $HELM_UPGRADE_INSTALL_CMD sourcegraph "$LOCAL_SOURCEGRAPH_CHARTS_FILE"

elif curl -s --connect-timeout 5 "$HELM_REPO" > /dev/null 2>&1; then

    # Check if the instance has network connectivity to the Helm repo, before running the Helm repo update command
    # Helm commands have a 2 minute connection timeout that's not configurable
    log "WARNING: Missing Sourcegraph Helm charts on disk at $LOCAL_SOURCEGRAPH_CHARTS_FILE"
    log "Upgrading Sourcegraph using charts from $HELM_REPO"
    $HELM_CMD repo update
    $HELM_UPGRADE_INSTALL_CMD sourcegraph sourcegraph/sourcegraph

else
    log "ERROR: Missing Sourcegraph Helm charts on disk at $LOCAL_SOURCEGRAPH_CHARTS_FILE, and cannot reach Helm repo at $HELM_REPO, skipping Sourcegraph upgrade"
fi

# Create the ingress
log "Creating ingress"
$KUBECTL_CMD create -f "$DEPLOY_PATH/ingress.yaml"

# Give the ingress time to deploy
sleep 5

# If the Executor Helm charts exist on disk, then use them
# Otherwise, use the Helm charts from the Helm repo
if [ -f "$LOCAL_EXECUTOR_CHARTS_FILE" ]; then

    log "Upgrading Executors using Helm charts on disk at $LOCAL_EXECUTOR_CHARTS_FILE"
    $HELM_UPGRADE_INSTALL_CMD executor "$LOCAL_EXECUTOR_CHARTS_FILE"

elif curl -s --connect-timeout 5 "$HELM_REPO" > /dev/null 2>&1; then

    # Check if the instance has network connectivity to the Helm repo, before running the Helm repo update command
    # Helm commands have a 2 minute connection timeout that's not configurable
    log "WARNING: Missing Executors Helm charts on disk at $LOCAL_EXECUTOR_CHARTS_FILE"
    log "Upgrading Executors using charts from $HELM_REPO"
    $HELM_CMD repo update
    $HELM_UPGRADE_INSTALL_CMD executor sourcegraph/sourcegraph-executor-k8s

else
    log "ERROR: Missing Executor Helm charts on disk at $LOCAL_EXECUTOR_CHARTS_FILE, and cannot reach Helm repo at $HELM_REPO, skipping Executor upgrade"
fi

recycle_pods_and_restart_k3s

# Write the new version number to both volumes, to pass the version match check on next reboot
HELM_APP_VERSION="$($HELM_CMD history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ':' -f 2 | xargs)"
echo "$HELM_APP_VERSION" | sudo tee "$AMI_ROOT_VOLUME_VERSION_FILE"
echo "$HELM_APP_VERSION" | sudo tee "$DATA_VOLUME_VERSION_FILE"

exit_script "$HELM_APP_VERSION"
