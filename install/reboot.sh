#!/usr/bin/bash


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

FINISHING_MESSAGE=""


##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# VARIABLES
###############################################################################

# Set INSTANCE_USERNAME to either ec2-user, if that's the current running user, otherwise sourcegraph
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
echo "Running as user: $INSTANCE_USERNAME"

# File path shortcuts
AMI_VERSION_FILE="/home/$INSTANCE_USERNAME/.sourcegraph-version"
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
LOCAL_BIN_PATH='/usr/local/bin'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'
VOLUME_VERSION_FILE='/mnt/data/.sourcegraph-version'

# Get the Sourcegraph release version from the user's home directory, in the AMI's root directory
AMI_VERSION=$(cat "$AMI_VERSION_FILE")

# Get the Sourcegraph release version from the data volume
# Not sure why we're checking if this file exists
if [ -f $VOLUME_VERSION_FILE ]; then
    VOLUME_VERSION=$(cat $VOLUME_VERSION_FILE)
fi

# Command shortcuts
KUBECTL="$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE"
HELM="$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE"
HELM_UPGRADE="$HELM upgrade -i -f ./override.yaml --version $AMI_VERSION"


###############################################################################
# This script gets run when instance is first started up from an AMI,
# and by cron on startup after every OS reboot, with a 10 second delay
###############################################################################

# Is this a normal reboot (versions match on root and data volumes), or the first boot after a data volume was from a prior version of Sourcegraph / is this an upgrade situation?
if [ -n "$VOLUME_VERSION" ] && [ "$VOLUME_VERSION" = "$AMI_VERSION" ]; then

    # If the Sourcegraph release version on the data volume matches the release version on the root volume, then this is not an upgrade
    echo "VOLUME_VERSION $VOLUME_VERSION = AMI_VERSION $AMI_VERSION, restarting k3s, deleting pods, and exiting script"

    # Store the finishing message here to be printed at the end of the script
    FINISHING_MESSAGE="Finishing reboot.sh after recreating pods and restarting k3s"

else

    # If we make it to this point, the versions don't match, and we're assuming it's an upgrade / needs to be redeployed
    echo "VOLUME_VERSION $VOLUME_VERSION != AMI_VERSION $AMI_VERSION, upgrading / redeploying the application"

    # Store the finishing message here to be printed at the end of the script
    FINISHING_MESSAGE="Finishing reboot.sh after upgrading / redeploying application"

    # If the k3s service is not running, get it running
    # NOTE: Cluster data will NOT be deleted
    if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then

        echo "k3s service is not running, starting it"

        # Stop all of the K3s containers and reset the containerd state
        sudo sh $LOCAL_BIN_PATH/k3s-killall.sh

        # Remove leftover creds and TLS certs
        sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/

        # Enable and start the k3s service
        sudo systemctl enable --now k3s

    fi

    # Log service status
    sudo systemctl status k3s.service

    # Delete any leftover ingresses from prior instances
    echo "Deleting any leftover ingresses from prior instances"
    $KUBECTL delete ingress sourcegraph-ingress

    # Restart the k3s service after deleting the ingress
    echo "Restarting k3s"
    sudo systemctl restart k3s

    # Give k3s some time to start up
    echo "Waiting 30 seconds for k3s to start up"
    sleep 30

    # Install or upgrade Sourcegraph and create ingress

    # Change to the deploy path directory, and if that fails, then we've got a major problem, just exit the script
    # $DEPLOY_PATH is on the root volume, why would it not be there, if cloning the repo failed while baking the image?
    cd "$DEPLOY_PATH" || exit 1

    # Helm repo update
    echo "Checking Helm repo for updates"
    $HELM repo update
    # This command fails without internet access; it's not a blocker, but it is a waste of time
    # Hang tight while we grab the latest from your chart repositories...
    # ...Unable to get an update from the "sourcegraph" chart repository (https://helm.sourcegraph.com/release):
    #         Get "https://helm.sourcegraph.com/release/index.yaml": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
    # Update Complete. ⎈Happy Helming!⎈

    # Install or upgrade Prometheus
    # Weird that we're using Helm for some of these commands, and kubectl for others
    echo "Installing / upgrading Prometheus"
    $KUBECTL apply -f ./prometheus-override.ConfigMap.yaml

    # If the Helm charts archive is in the $DEPLOY_PATH, then use it to upgrade or install Sourcegraph
    # Why / how would this file not be in this directory?
    echo "Installing / upgrading Sourcegraph"
    if [ -f ./sourcegraph-charts.tgz ]; then
        $HELM_UPGRADE sourcegraph ./sourcegraph-charts.tgz
    else
    # If the archive is not in the $DEPLOY_PATH, then install Sourcegraph from the public Helm repo
        $HELM_UPGRADE sourcegraph sourcegraph/sourcegraph
    fi

    # Create the ingress
    echo "Creating ingress"
    $KUBECTL create -f ./ingress.yaml

    # Wait 5 seconds for the Sourcegraph instance and ingress to come up
    sleep 5

    # If the Executor Helm charts archive is in the $DEPLOY_PATH, then use it to upgrade or install Executors
    # Why / how would this file not be in this directory?
    echo "Deploying / upgrading Executors, if configured"
    if [ -f ./sourcegraph-executor-k8s-charts.tgz ]; then
        $HELM_UPGRADE executor ./sourcegraph-executor-k8s-charts.tgz
    else
    # If the archive is not in the $DEPLOY_PATH, then install Executor from the public Helm repo
        $HELM_UPGRADE executor sourcegraph/sourcegraph-executor-k8s
    fi

    # Get the Sourcegraph release version from the Helm deployment
    HELM_APP_VERSION=$($HELM history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)

    # Log HELM_APP_VERSION
    echo "HELM_APP_VERSION: $HELM_APP_VERSION"

    # If the Helm app version isn't an empty string, then write it to the data and root volumes, to be checked by the next run of this script
    # Why would the Helm app version be an empty string? If that case is persistent across reboots, these values would never get written, thus match, and this code path would be followed after each reboot
    if [ "$HELM_APP_VERSION" != "" ]; then
        echo "$HELM_APP_VERSION" | sudo tee "$VOLUME_VERSION_FILE"
        echo "$HELM_APP_VERSION" | sudo tee "$AMI_VERSION_FILE"
    else
        echo "Failed to get Sourcegraph release version from Helm"
    fi

fi

# Log pod statuses
echo "Logging pod statuses"
$LOCAL_BIN_PATH/kubectl get pods

# Delete and recreate all pods, regardless of if they're old or new, seems to help the appliction start up
echo "Deleting and recreating all pods"
$LOCAL_BIN_PATH/kubectl delete pods --all

# Wait a minute for the pods to come back up after deleting and recreating them
echo "Waiting 60 seconds for pods to come back up"
sleep 60

# Restart the k3s service again, in case any containers are still in a CrashLoopBackOff state
# However, this should not affect a running instance
echo "Restarting k3s in case any containers are still in a CrashLoopBackOff state"
sudo systemctl restart k3s

# Wait for pods to stabilize
echo "Waiting 30 seconds to let pods stabilize"
sleep 30

# Log pod statuses again
echo "Logging pod statuses"
$LOCAL_BIN_PATH/kubectl get pods

# Log the finishing message
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$DATE_TIME] $FINISHING_MESSAGE"
