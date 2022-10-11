#!/usr/bin/bash

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# VARIABLES
###############################################################################
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
AMI_VERSION=$(cat /home/"$INSTANCE_USERNAME"/.sourcegraph-version)
VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
LOCAL_BIN_PATH='/usr/local/bin'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'

###############################################################################
# This script will be run when instance is first started up from an AMI,
# as well as on every system reboot.
###############################################################################
# Delete any existing ingress from old instances before restarting k3s
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
sleep 5

# Exit if AMI version is the same version as the volume
if [ "$VOLUME_VERSION" = "$AMI_VERSION" ]; then
    exit 0
fi

# Reset the containerd state if k3s is not starting ( data will not be deleted)
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
    sudo systemctl enable k3s
else
    sudo systemctl restart k3s
fi

# Install or upgrade Sourcegraph and create ingress
sleep 10
cd "$DEPLOY_PATH" || exit
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$AMI_VERSION" sourcegraph ./sourcegraph-charts.tgz
echo "$AMI_VERSION" | sudo tee /mnt/data/.sourcegraph-version
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f ./ingress.yaml
sleep 60 && sudo systemctl restart k3s
