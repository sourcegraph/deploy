#!/usr/bin/bash

# TODO:
# Logging
# Infinite loop of checking for pods not running, and restarting the k3s.service and waiting?


###############################################################################
# LOGGING
###############################################################################

# Set the log output file
LOG_FILE='/var/log/reboot.sh.log'

# Log to both console and file
exec > >(sudo tee -a "$LOG_FILE") 2>&1

# Log a starting message
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$DATE_TIME] Starting reboot.sh"


##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# VARIABLES
###############################################################################

# Set INSTANCE_USERNAME to either ec2-user, if that's the current running user, otherwise sourcegraph
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'

# File paths
AMI_VERSION_FILE="/home/$INSTANCE_USERNAME/.sourcegraph-version"
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
LOCAL_BIN_PATH='/usr/local/bin'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'
VOLUME_VERSION_FILE='/mnt/data/.sourcegraph-version'

# Get the Sourcegraph release version from the user's home directory, in the AMI's root directory
AMI_VERSION=$(cat "$AMI_VERSION_FILE")


###############################################################################
# This script gets run when instance is first started up from an AMI,
# and by cron on startup after every OS reboot
###############################################################################

# If the Sourcegraph release version on the data volume matches the release version on the root volume, then this is not an upgrade
# Restart k3s and exit
if [ -f $VOLUME_VERSION_FILE ]; then
    VOLUME_VERSION=$(cat $VOLUME_VERSION_FILE)

    if [ "$VOLUME_VERSION" = "$AMI_VERSION" ]; then

        echo "VOLUME_VERSION $VOLUME_VERSION = AMI_VERSION $AMI_VERSION, restarting k3s and exiting script"
        sudo systemctl restart k3s
        exit 0

    fi
fi

# If we make it to this point, the versions don't match, and we're assuming it's an upgrade
echo "VOLUME_VERSION $VOLUME_VERSION != AMI_VERSION $AMI_VERSION, resetting state and redeploying Sourcegraph"

# Note that the @reboot cronjob has a 10 second sleep before calling this script, to give k3s time to start up

# If the k3s service is not running, reset the containerd state
# NOTE: Cluster data will NOT be deleted
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then

    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh

    # Remove leftover creds and TLS certs
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/

    # Enable and start the k3s service
    sudo systemctl enable --now k3s

else
# The k3s services is running

    # Delete any leftover ingresses from old instances, before restarting k3s
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress

fi

# Restart k3s, and if successful, then wait for it to come up, whether it started at boot time, or was just started in the previous if block
sudo systemctl restart k3s && sleep 30

# Install or upgrade Sourcegraph and create ingress

# Change to the deploy path directory, and if that fails, then we've got a major problem, just exit the script
# $DEPLOY_PATH is on the root volume, why would it not be there?
cd "$DEPLOY_PATH" || exit

# Helm repo update
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE repo update
# This command fails without internet access, but is not a breaking fail
# Hang tight while we grab the latest from your chart repositories...
# ...Unable to get an update from the "sourcegraph" chart repository (https://helm.sourcegraph.com/release):
#         Get "https://helm.sourcegraph.com/release/index.yaml": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
# Update Complete. ⎈Happy Helming!⎈

# Install or upgrade Prometheus
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f ./prometheus-override.ConfigMap.yaml

# If the Helm charts archive is in the $DEPLOY_PATH, then use it to upgrade or install Sourcegraph
# Why / how would this file not be in this directory?
if [ -f ./sourcegraph-charts.tgz ]; then
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" sourcegraph ./sourcegraph-charts.tgz
else
# If the archive is not in the $DEPLOY_PATH, then install Sourcegraph from the public Helm chart repo
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" sourcegraph sourcegraph/sourcegraph
fi

# Create the ingress
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f ./ingress.yaml

# Wait 5 seconds for the Sourcegraph instance and ingress to come up
sleep 5

# If the Executor Helm charts archive is in the $DEPLOY_PATH, then use it to upgrade or install Executors
# Why / how would this file not be in this directory?
if [ -f ./sourcegraph-executor-k8s-charts.tgz ]; then
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" executor ./sourcegraph-executor-k8s-charts.tgz
else
# If the archive is not in the $DEPLOY_PATH, then install Executor from the public Helm chart repo
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" executor sourcegraph/sourcegraph-executor-k8s
fi

# Delete and recreate all pods, regardless of if they're old or new, just because the release versions didn't match
$LOCAL_BIN_PATH/kubectl delete pods --all

# Wait a minute for the pods to come back up after deleting and recreating them
sleep 60

# Restart the k3s service again, in case any containers are still in a CrashLoopBackOff state
# However, this should not affect a running instance
sudo systemctl restart k3s

# Get the Sourcegraph release version from the Helm deployment
HELM_APP_VERSION=$($LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)

# Log HELM_APP_VERSION
echo "HELM_APP_VERSION: $HELM_APP_VERSION"

# If the Helm app version isn't an empty string, then write it to the data and root volumes, to be checked by the next run of this script
# Why would the Helm app version be an empty string? If that case is persistent across reboots, these values would never get written, thus match, and this code path would be followed after each reboot
[ "$HELM_APP_VERSION" != "" ] && echo "$HELM_APP_VERSION" | sudo tee "$VOLUME_VERSION_FILE"
[ "$HELM_APP_VERSION" != "" ] && echo "$HELM_APP_VERSION" | sudo tee "$AMI_VERSION_FILE"

# Log a finishing message
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$DATE_TIME] Finishing reboot.sh"
