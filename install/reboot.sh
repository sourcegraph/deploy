#!/usr/bin/bash

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# VARIABLES
###############################################################################
AMI_VERSION=$(cat /home/ec2-user/.sourcegraph-version)
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
DEPLOY_PATH='/home/ec2-user/deploy/install'
LOCAL_BIN_PATH='/usr/local/bin'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'

###############################################################################
# This script will be run when instance is first started up from an AMI,
# as well as on every system reboot.
###############################################################################
# Delete any existing ingress from old instances before restarting k3s
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
sleep 5 && sudo systemctl restart k3s

# Reset the containerd state if k3s is not starting ( data will not be deleted)
if sudo systemctl status k3s.service | grep -q 'k3s.service failed'; then
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
    sudo systemctl enable k3s
fi

# Install or upgrade Sourcegraph and create ingress
# TODO: B - Compare versions before performing upgrades
sleep 10
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f $DEPLOY_PATH/override.yaml --version "$AMI_VERSION" sourcegraph $DEPLOY_PATH/sourcegraph-charts.tgz
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f $DEPLOY_PATH/ingress.yaml
sleep 60 && sudo systemctl restart k3s
