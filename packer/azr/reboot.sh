#!/usr/bin/env bash

###############################################################################
# VARIABLES
###############################################################################
[ "$(whoami)" == 'ec2-user' ] && INSTANCE_USERNAME='ec2-user' || INSTANCE_USERNAME='sourcegraph'
IMAGE_VERSION=$(cat /home/"$INSTANCE_USERNAME"/.sourcegraph-version)
DEPLOY_PATH="/home/$INSTANCE_USERNAME"
LOCAL_BIN_PATH='/usr/local/bin'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'
###############################################################################
# This script will be run when instance is first started up from an image,
# as well as on every system reboot.
###############################################################################
# Exit if image version is the same version as the volume
if [ -f /mnt/data/.sourcegraph-version ]; then
    VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
    if [ "$VOLUME_VERSION" = "$IMAGE_VERSION" ]; then
        exit 0
    fi
fi

# Reset the containerd state if k3s is not starting ( data will not be deleted)
if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
    # Stop all of the K3s containers and reset the containerd state
    sudo sh $LOCAL_BIN_PATH/k3s-killall.sh

    # Remove leftovers TLS certs and cred
    sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/

    # Enable K3s service on boot
    sudo systemctl enable k3s

    # Start K3s service now
    sudo systemctl start k3s
else
    # Delete any existing ingress from old instances before restarting k3s
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
    sleep 10
    sudo systemctl restart k3s
fi

# Install or upgrade Sourcegraph and create ingress
sleep 10
cd "$DEPLOY_PATH" || exit
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE repo update
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f ./prometheus-override.ConfigMap.yaml
if [ -f ./sourcegraph-charts.tgz ]; then
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$IMAGE_VERSION" sourcegraph ./sourcegraph-charts.tgz
else
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$IMAGE_VERSION" sourcegraph sourcegraph/sourcegraph
fi
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f ./ingress.yaml
sleep 60 && sudo systemctl restart k3s

HELM_APP_VERSION=$(/usr/local/bin/helm --kubeconfig /etc/rancher/k3s/k3s.yaml history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)

echo "${HELM_APP_VERSION}" | sudo tee /mnt/data/.sourcegraph-version
echo "${HELM_APP_VERSION}" | sudo tee /home/"$INSTANCE_USERNAME"/.sourcegraph-version
