#!/usr/bin/env bash

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Variables
###############################################################################
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
INSTANCE_USERNAME='sourcegraph'
VOLUME_DEVICE_NAME='/dev/sdb'
LOCAL_BIN_PATH='/usr/local/bin'
SHELL='/bin/bash'
USER_ROOT_PATH="/home/$INSTANCE_USERNAME/"
DEPLOY_PATH="/home/$INSTANCE_USERNAME/deploy/install"
SOURCEGRAPH_VERSION=$(cat /home/"$INSTANCE_USERNAME"/.sourcegraph-version)

###############################################################################
# Prepare the system
###############################################################################
if [ -f /mnt/data/.sourcegraph-version ]; then
    sleep 25 && bash $DEPLOY_PATH/reboot.sh
    exit 0
fi

# cd into the deployment repository
cd $DEPLOY_PATH || exit
# Add version number to disk for future upgrades purpose
sudo mkdir -p /mnt/data

###############################################################################
# Configure data volumes
###############################################################################
# Format (if necessary) and mount the EBS volume
device_fs=$(sudo lsblk $VOLUME_DEVICE_NAME --noheadings --output fsType)
if [ "$device_fs" == "" ]; then
    sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard $VOLUME_DEVICE_NAME
    sudo e2label $VOLUME_DEVICE_NAME /mnt/data # Add label to volume device
fi
sudo mount $VOLUME_DEVICE_NAME /mnt/data
# Mount data disk on reboots by linking disk label to data root path
sudo echo "LABEL=/mnt/data  /mnt/data  ext4  discard,defaults,nofail  0  2" | sudo tee -a /etc/fstab
sudo umount /mnt/data
sudo mount -a
# Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
sudo mkdir -p /mnt/data/kubelet /var/lib/kubelet
sudo echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" | sudo tee -a /etc/fstab
sudo mount -a

# Put persistent volume pod storage in our data disk, and k3s's embedded database there too (it
# must be kept around in order for k3s to keep PVs attached to the right folder on disk if a node
# is lost (i.e. during an upgrade of Sourcegraph), see https://github.com/rancher/local-path-provisioner/issues/26
sudo mkdir -p /mnt/data/db
sudo mkdir -p /var/lib/rancher/k3s/server
sudo ln -s /mnt/data/db /var/lib/rancher/k3s/server/db
sudo mkdir -p /mnt/data/storage
sudo mkdir -p /var/lib/rancher/k3s
sudo ln -s /mnt/data/storage /var/lib/rancher/k3s/storage

###############################################################################
# Install k3s (Kubernetes single-machine deployment)
###############################################################################
curl -sfL https://get.k3s.io | K3S_TOKEN=none sh -s - \
    --node-name sourcegraph-0 \
    --write-kubeconfig-mode 644 \
    --cluster-cidr 10.10.0.0/16 \
    --kubelet-arg containerd=/run/k3s/containerd/containerd.sock \
    --etcd-expose-metrics true

# Confirm k3s and kubectl are up and running
sleep 30 && k3s kubectl get node

# Correct permissions of k3s config file
sudo chown $INSTANCE_USERNAME /etc/rancher/k3s/k3s.yaml
sudo chmod go-r /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'

###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Confirm Helm is up and running
$LOCAL_BIN_PATH/helm version --short

# # Store Sourcegraph Helm charts locally
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE repo add sourcegraph https://helm.sourcegraph.com/release
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph

# Create override configMap for prometheus before startup Sourcegraph
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f /home/sourcegraph/deploy/install/prometheus-override.ConfigMap.yaml
$LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f /home/sourcegraph/deploy/install/override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph sourcegraph/sourcegraph
$LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f /home/sourcegraph/deploy/install/ingress.yaml

# Start Sourcegraph on next reboot
echo "@reboot sleep 30 && bash $DEPLOY_PATH/reboot.sh" | crontab -

# Store the version number from helm chart history
HELM_APP_VERSION=$(/usr/local/bin/helm --kubeconfig /etc/rancher/k3s/k3s.yaml history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)
[ "$HELM_APP_VERSION" != "" ] && echo "$HELM_APP_VERSION" | sudo tee /mnt/data/.sourcegraph-version
[ "$SOURCEGRAPH_VERSION" == "" ] && echo "$HELM_APP_VERSION" | sudo tee "$USER_ROOT_PATH"/.sourcegraph-version

# Clean up files
sudo cp /etc/rancher/k3s/k3s.yaml /home/sourcegraph/.kube/config
sudo rm -f /home/sourcegraph/install.sh
sudo mv -f sourcegraph-"$HELM_APP_VERSION".tgz sourcegraph-charts.tgz
