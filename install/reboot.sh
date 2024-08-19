#!/usr/bin/bash
###############################################################################
# This script will be run when instance is first started up from an AMI,
# as well as on every reboot.
###############################################################################

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# VARIABLES
###############################################################################
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
AMI_VERSION=$(cat /home/"$INSTANCE_USERNAME"/.sourcegraph-version)
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
LOCAL_BIN_PATH='/usr/local/bin'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'

# If the Sourcegraph version stored on the data volume matches the version stored on the AMI's root volume
# Then this is a regular reboot, not a first time startup or upgrade
# Recycle pods and restart k3s to clear out any possible startup issues
# Exit the script early
if [ -f /mnt/data/.sourcegraph-version ]; then
    VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
    if [ "$VOLUME_VERSION" = "$AMI_VERSION" ]; then
        # Recycle all pods
        $LOCAL_BIN_PATH/kubectl delete pods --all
        # Restart k3s
        sudo systemctl restart k3s
        exit 0
    fi
fi

# Script continues if this is either a first time startup or an upgrade

# If k3s is not starting / running successfully, then reset containerd state, so that it becomes ready for the Sourcegraph upgrade
# NOTE: Cluster data is NOT deleted in this process
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
    # Enable k3s in this cluster and start the unit now
    sudo systemctl enable --now k3s
else
    # If k3s is running successfully, then delete the existing ingress, to prepare for the upgrade
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
fi

# Restart the k3s service after the above changes
sudo systemctl restart k3s

# Give k3s some time to start up
sleep 30

# Install or upgrade Sourcegraph and create ingress
cd "$DEPLOY_PATH" || exit

# Try to pull the latest Helm chart
# This takes 30+ seconds to timeout if the instance does not have internet connectivity open to our Helm repo
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE repo update

# Apply the Prometheus override
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f ./prometheus-override.ConfigMap.yaml

# If the Sourcegraph Helm charts exist on disk (they always should on a running instance), then use them
# Otherwise, use the Helm charts at the default path
if [ -f ./sourcegraph-charts.tgz ]; then
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" sourcegraph ./sourcegraph-charts.tgz
else
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" sourcegraph sourcegraph/sourcegraph
fi

# Create the ingress
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f ./ingress.yaml

# Give the ingress time to deploy
sleep 5

# If the Executor Helm charts exist on disk, then use them
# Otherwise, use the Helm charts at the default path
if [ -f ./sourcegraph-executor-k8s-charts.tgz ]; then
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" executor ./sourcegraph-executor-k8s-charts.tgz
else
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" executor sourcegraph/sourcegraph-executor-k8s
fi

# Recycle all pods
$LOCAL_BIN_PATH/kubectl delete pods --all

# Wait a minute for the new pods to start up
sleep 60

# Restart k3s again in case it's still in crashloopbackoff
# This should not affect a running instance
sudo systemctl restart k3s

# Write the new version number to both volumes, to pass the version match check on next reboot
HELM_APP_VERSION=$(/usr/local/bin/helm --kubeconfig /etc/rancher/k3s/k3s.yaml history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)
[ "$HELM_APP_VERSION" != "" ] && echo "$HELM_APP_VERSION" | sudo tee /mnt/data/.sourcegraph-version
[ "$HELM_APP_VERSION" != "" ] && echo "$HELM_APP_VERSION" | sudo tee /home/"$INSTANCE_USERNAME"/.sourcegraph-version
