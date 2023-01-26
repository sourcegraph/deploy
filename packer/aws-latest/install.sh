#!/usr/bin/env bash

###############################################################################
# Variables
###############################################################################
SOURCEGRAPH_SIZE=${SOURCEGRAPH_SIZE:-XS} # Must be uppercase XS/S/...
DEPLOY_PATH='/home/ec2-user/deploy/install'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'
LOCAL_BIN_PATH='/usr/local/bin'
###############################################################################
# Prepare the system
###############################################################################
if [ -f /mnt/data/.sourcegraph-version ]; then
    sleep 25 && bash $DEPLOY_PATH/reboot.sh
    exit 0
fi

###############################################################################
# If running as root, de-escalate to a regular user. The remainder of this script
# will always use `sudo` to indicate where root is required, so that it is clear
# what does and does not require root in our installation process.
###############################################################################
# If running as root, deescalate
if [ $UID -eq 0 ]; then
    chown ec2-user "$0" # /var/lib/cloud/instance/scripts/part-001
    exec su ec2-user "$0" -- "$@"
    # nothing will be executed beyond here (exec replaces the running process)
fi

# Reset the containerd state if k3s is not starting
# NOTE: Cluster data will NOT be deleted
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
    # Enable k3s in this cluster and start the unit now
    sudo systemctl enable --now k3s
else
    # Delete any existing ingress from old instances before restarting k3s
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
fi
sudo systemctl restart k3s
sleep 30

# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'

cd $DEPLOY_PATH || exit
cp override."$SOURCEGRAPH_SIZE".yaml override.yaml

# Update information of available charts from Sourcegraph chart repository
attempt=1
while [ "$SOURCEGRAPH_VERSION" == "" ]; do
    $LOCAL_BIN_PATH/helm --kubeconfig=$KUBECONFIG_FILE repo update
    SOURCEGRAPH_VERSION=$($LOCAL_BIN_PATH/helm inspect chart sourcegraph/sourcegraph | grep version: | sed -r 's/version: (.*)/\1/')
    attempt=$((attempt + 1))
    if [ $attempt -eq 6 ]; then exit; fi
    sleep 10
done
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph
mv ./sourcegraph-"$SOURCEGRAPH_VERSION".tgz ./sourcegraph-charts.tgz
helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph-migrator
mv ./sourcegraph-migrator-"$SOURCEGRAPH_VERSION".tgz ./sourcegraph-migrator-charts.tgz

# Create override configMap for prometheus before startup Sourcegraph
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f /home/ec2-user/deploy/install/prometheus-override.ConfigMap.yaml
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f /home/ec2-user/deploy/install/override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph sourcegraph/sourcegraph
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f /home/ec2-user/deploy/install/ingress.yaml

# Generate files to save instance info in volumes for upgrade purpose
echo "${SOURCEGRAPH_VERSION}" | sudo tee /home/ec2-user/.sourcegraph-version
echo "${SOURCEGRAPH_VERSION}-base" | sudo tee /mnt/data/.sourcegraph-version
echo "${SOURCEGRAPH_SIZE}" | sudo tee /home/ec2-user/.sourcegraph-size

# Restart again to fix possible crash loop backoff
sleep 60 && sudo systemctl restart k3s

# Start Sourcegraph on next reboot
echo "@reboot sleep 10 && bash $DEPLOY_PATH/reboot.sh" | crontab -
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo rm -f /home/ec2-user/install.sh