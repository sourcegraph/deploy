#!/usr/bin/bash

###############################################################################
# Cron runs this script on every boot
# Customers can run this script manually
# Logs:
#   script logs in $LOG_FILE
#   cron logs in /var/spool/mail/$INSTANCE_USERNAME
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
COREDNS_FILE="$RANCHER_SERVER_PATH/manifests/coredns.yaml"


### Reusable commands to maintain consistency for the commands this script runs multiple times
HELM_CMD="$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE"
HELM_UPGRADE_INSTALL_CMD="$HELM_CMD upgrade --install --values $DEPLOY_PATH/override.yaml"
KUBECTL_CMD="$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE"
KUBECTL_GET_PODS_CMD="$KUBECTL_CMD get pods -A -o wide"
KUBECTL_GET_ALL_CMD="$KUBECTL_CMD get all -A"
KUBECTL_DELETE_PODS_ALL_CMD="$LOCAL_BIN_PATH/kubectl delete rs,pods --all"
RESTART_K3S_CMD="sudo systemctl restart k3s"


### Logging
# Configure script to output to both console and file
LOG_FILE="/var/log/reboot.sh.log"
exec > >(sudo tee -a "$LOG_FILE") 2>&1


### Functions
function check_pod_statuses() {

  # Output the statuses of all pods
  log "Checking statuses of all resources"
  $KUBECTL_GET_ALL_CMD

  # If any pods are not running, then call them out specifically with a warning
  COUNT_OF_PODS_NOT_RUNNING=$($KUBECTL_GET_PODS_CMD | grep -v -e Running -e Completed -e NAMESPACE -c)
  if [[ $COUNT_OF_PODS_NOT_RUNNING -ne 0 ]]; then
    printf "\n\n"
    log "WARNING: $COUNT_OF_PODS_NOT_RUNNING pods not running:"
    $KUBECTL_GET_PODS_CMD | grep -v -e Running -e Completed
    printf "\n\n"
  fi
}

# Pass the version number when calling this function
function exit_script() {
  check_pod_statuses
  log "Giving a 10 second cooling period"
  sleep 10
  check_pod_statuses
  log "Started Sourcegraph on version $1"
  log "Script finished after $(($(date +%s) - START_TIME)) seconds"
  exit 0
}

function get_sourcegraph_version_from_helm() {
  $HELM_CMD history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ':' -f 2 | xargs
}

function k3s_not_running() {
  ! sudo systemctl status k3s.service | grep -q 'active (running)'
}

function log() {
  # Define log function for consistent output format
  echo "$(date '+%Y-%m-%d - %H:%M:%S') - $0 - $1"
}

function override_coredns() {
  # Allows for instances to resolve internal DNS in AWS / GPC VPCs via VPC metadata endpoint
  # Before
  # forward . /etc/resolv.conf
  # After
  # forward . 169.254.169.254 /etc/resolv.conf { policy sequential }
  # This sed command appears to be safe to be re-run
  log "Overriding k3s coredns"
  sudo sed -i 's#^\(\s*\)forward .*#\1forward . 169.254.169.254 /etc/resolv.conf { policy sequential }#' $COREDNS_FILE
  restart_k3s
}

function recycle_pods_and_restart_k3s() {
  log "Recycling replicaSets and pods"
  $KUBECTL_DELETE_PODS_ALL_CMD
  # Could change this to a while [ kubectl get pods | grep -v Running ], with a maximum wait time of 60 seconds, then sleep 5 seconds
  log "Giving pods 60 seconds to start up"
  sleep 60
  # Restart k3s in case pods are stuck in a crashloopbackoff
  # This should not affect a running instance
  restart_k3s
}

function reset_and_enable_k3s() {
  # install.sh leaves the k3s service disabled,
  # so this runs on a newly deployed instance's first boot
  # and may run if the instance is in a failing state and rebooted
  # NOTE: Cluster data / customer content is NOT deleted in this process

  log "Reenabling k3s service"

  # Stop all of the K3s containers and reset the containerd state
  sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
  # Remove leftover cred and TLS cert
  sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
  # Enable and start the k3s service
  sudo systemctl enable --now k3s
}

function restart_k3s() {
  log "Restarting the k3s service"
  $RESTART_K3S_CMD
}


### Script execution starts here
log "Script started"
START_TIME=$(date +%s)

# Fix the DNS issue at the beginning of the script
# so that any network connections in the script are more likely to work
override_coredns

# Check the pod statuses at the start of the script to log the starting state
check_pod_statuses

### Get the Sourcegraph version numbers from the root and data volume
### Try multiple sources in case there's an issue
### Breaking this out into multiple if / then statements to avoid multilevel nested if statements
# Get the Sourcegraph version number from the AMI's root volume
# This should be the version of Docker images and Helm charts already baked into the AMI
if [ -f "$AMI_ROOT_VOLUME_VERSION_FILE" ]; then
  AMI_VERSION="$(cat "$AMI_ROOT_VOLUME_VERSION_FILE")"
  log "AMI root volume version: $AMI_VERSION"
else
  log "WARNING: Missing AMI root volume version file at $AMI_ROOT_VOLUME_VERSION_FILE"
  # Try to install anyway
fi

# If the script wasn't able to read the $AMI_VERSION from the $AMI_ROOT_VOLUME_VERSION_FILE,
# then try to capture it from Helm
if [ -z "$AMI_VERSION" ]; then
  log "WARNING: Failed to get AMI root volume version from file at $AMI_ROOT_VOLUME_VERSION_FILE"
  AMI_VERSION=$(get_sourcegraph_version_from_helm)
  log "Last installed version from Helm history: $AMI_VERSION"
fi

# If the script has $AMI_VERSION, then add it to the Helm command
# Otherwise, something's broken enough for the customer to open a support ticket
if [ -n "$AMI_VERSION" ]; then
  # Add the version number to the Helm command
  HELM_UPGRADE_INSTALL_CMD="$HELM_UPGRADE_INSTALL_CMD --version $AMI_VERSION"
else
  log "ERROR: Failed to read AMI version from either $AMI_ROOT_VOLUME_VERSION_FILE or Helm install history, contact Sourcegraph Customer Support"
fi

# Get the Sourcegraph version number from the attached data volume
# This should be the version of the databases
# install.sh appends '-base' to the version number on the data volume
# to ensure that it doesn't match the version number on the root volume
# so this script runs the whole way through on first boot
if [ -f "$DATA_VOLUME_VERSION_FILE" ]; then
  DATA_VOLUME_VERSION="$(cat "$DATA_VOLUME_VERSION_FILE")"
  log "Data volume version: $DATA_VOLUME_VERSION"
else
  log "WARNING: Missing data volume version file at $DATA_VOLUME_VERSION_FILE"
  # Try to install anyway
fi


### Determine the code path to take
# If the customer has created an override file on the data volume,
# then use it, by appending it to the Helm upgrade install command
# Always reinstall Sourcegraph on every boot when there's a custom override.yaml file,
# so the customer can apply these changes by rebooting the instance, or running this script
if [ -f "$CUSTOMER_OVERRIDE_FILE" ]; then
  log "Found custom Helm values file at $CUSTOMER_OVERRIDE_FILE, reinstalling Sourcegraph to use the custom Helm values file"
  # Append the customer's override file to the command after the default values file, so the customer's values override the defaults we provide
  HELM_UPGRADE_INSTALL_CMD="$HELM_UPGRADE_INSTALL_CMD --values $CUSTOMER_OVERRIDE_FILE"

# If the k3s service is not running, then force a reinstallation to remediate it
elif k3s_not_running; then

  if [[ $DATA_VOLUME_VERSION =~ .*-base ]]; then
    log "First time startup, installing Sourcegraph version $AMI_VERSION"
  else
    log "ERROR: k3s.service is not running, reinstalling Sourcegraph version $AMI_VERSION to remediate"
  fi

# If the version on the data volume matches the version on the root volume
# and the versions are not empty
# (not performing regex match to avoid different behaviour for non-release builds)
# and there's no $CUSTOMER_OVERRIDE_FILE
# then this is a regular reboot
# Note: if $AMI_VERSION is empty, Helm install will fail on this execution of this script
  # Error: "helm upgrade" requires 2 arguments
# but this execution of this script should write the most recently installed version to these files
elif [ "$AMI_VERSION" = "$DATA_VOLUME_VERSION" ] && [ -n "$AMI_VERSION" ]; then
  log "Versions match, k3s is running, and no custom override file; starting Sourcegraph"
  # Recycle pods and restart k3s to clear out possible startup issues
  recycle_pods_and_restart_k3s
  # Exit the script early
  exit_script "$AMI_VERSION"

# Otherwise, reinstall Sourcegraph
else
  log "Installing Sourcegraph version $AMI_VERSION"
fi


### Prepare for installation

# Check if k3s is not starting / running
# then reset containerd state
if k3s_not_running; then
  reset_and_enable_k3s
fi

# Delete the existing ingress, to prepare for the upgrade
# It's fine if the ingress doesn't exist, ex. first startup, this will just print an error and continue
# Error from server (NotFound): ingresses.networking.k8s.io "sourcegraph-ingress" not found
# NOTE: User downtime starts now, try to keep the downtime as short as possible
log "Deleting ingress"
$KUBECTL_CMD delete ingress sourcegraph-ingress

# Restart the k3s service after either of the above changes
restart_k3s

# Give k3s time to start up
# To try and keep the user downtime as short as possible,
# we could change this to
# while k3s_not_running()
# with a maximum wait time of 25 seconds (log a warning if this limit is hit)
# then sleep 5 seconds
log "Giving the k3s service 30 seconds to start up"
sleep 30


### Install or upgrade Sourcegraph, and recreate the ingress
log "Changing directory to $DEPLOY_PATH"
cd "$DEPLOY_PATH" || exit 1

# Apply the Prometheus override
log "Applying Prometheus override"
$KUBECTL_CMD apply -f "$DEPLOY_PATH/prometheus-override.ConfigMap.yaml"

# Prioritize updating the Helm chart from our $HELM_REPO, if reachable
# So that customers get the latest version of the Helm chart for their Sourcegraph version
# Helm commands have a 2 minute connection timeout that's not configurable,
# so check if the instance has network connectivity to the Helm repo
# before running the Helm repo update command
CAN_CONNECT_TO_HELM_REPO=""
if curl -s --connect-timeout 3 "$HELM_REPO" > /dev/null 2>&1; then
  CAN_CONNECT_TO_HELM_REPO="true"
fi

# Install / upgrade Sourcegraph deployment
if [ "$CAN_CONNECT_TO_HELM_REPO" ]; then

  log "Connection to $HELM_REPO succeeded, updating helm chart"
  $HELM_CMD repo update
  log "Upgrading Sourcegraph using charts from $HELM_REPO"
  $HELM_UPGRADE_INSTALL_CMD sourcegraph sourcegraph/sourcegraph

elif [ -f "$LOCAL_SOURCEGRAPH_CHARTS_FILE" ]; then

  log "Connection to $HELM_REPO failed, upgrading Sourcegraph using Helm charts on disk at $LOCAL_SOURCEGRAPH_CHARTS_FILE"
  $HELM_UPGRADE_INSTALL_CMD sourcegraph "$LOCAL_SOURCEGRAPH_CHARTS_FILE"

else
  log "ERROR: Cannot reach Helm repo at $HELM_REPO, and missing Sourcegraph Helm charts on disk at $LOCAL_SOURCEGRAPH_CHARTS_FILE, skipping Sourcegraph upgrade. Contact Sourcegraph Customer Support."
fi

# Create the ingress
log "Creating ingress"
$KUBECTL_CMD create -f "$DEPLOY_PATH/ingress.yaml"

# NOTE: User downtime can end any time from now, depending on pod startup time and success

# Give the ingress time to deploy
log "Giving the ingress 5 seconds to start up"
sleep 5

# Install / upgrade Executors deployment
if [ "$CAN_CONNECT_TO_HELM_REPO" ]; then

  log "Upgrading Executors using charts from $HELM_REPO"
  $HELM_UPGRADE_INSTALL_CMD executor sourcegraph/sourcegraph-executor-k8s

elif [ -f "$LOCAL_EXECUTOR_CHARTS_FILE" ]; then

  log "Connection to $HELM_REPO failed, upgrading Executors using Helm charts on disk at $LOCAL_EXECUTOR_CHARTS_FILE"
  $HELM_UPGRADE_INSTALL_CMD executor "$LOCAL_EXECUTOR_CHARTS_FILE"

else
  log "ERROR: Cannot reach Helm repo at $HELM_REPO, and missing executor Helm charts on disk at $LOCAL_EXECUTOR_CHARTS_FILE, skipping Executors upgrade. Contact Sourcegraph Customer Support."
fi

recycle_pods_and_restart_k3s

# Write the new version number to both volumes, to pass the version match check on next reboot
HELM_APP_VERSION=$(get_sourcegraph_version_from_helm)
echo "$HELM_APP_VERSION" | sudo tee "$AMI_ROOT_VOLUME_VERSION_FILE" "$DATA_VOLUME_VERSION_FILE"

exit_script "$HELM_APP_VERSION"
