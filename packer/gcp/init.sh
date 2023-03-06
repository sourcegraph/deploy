#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# ACTION REQUIRED IF RUNNING THIS SCRIPT MANUALLY
# IMPORTANT: Keep this commented when building with the packer pipeline
###############################################################################
INSTANCE_VERSION="" # e.g. 4.0.1
# INSTANCE_SIZE="XS"  # e.g. XS / S / M / L / XL

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Variables
###############################################################################
SOURCEGRAPH_VERSION=$INSTANCE_VERSION
SOURCEGRAPH_SIZE=$INSTANCE_SIZE
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy.git'
DEPLOY_PATH='/root/deploy/install'
USER_ROOT_PATH="/home/sourcegraph"
SHELL=/bin/bash

###############################################################################
# Prepare the system
###############################################################################
# Update
sudo apt-get update -y

# Clone the deployment repository
DEPLOY_PATH="$USER_ROOT_PATH/deploy/install"
cd
# git clone https://github.com/sourcegraph/SetupWizard.git
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cd $DEPLOY_PATH
cp override."$SOURCEGRAPH_SIZE".yaml override.yaml

sudo mkdir -p /mnt/data

# ###############################################################################
# # Kernel parameters required by Sourcegraph
# ###############################################################################
# # These must be set in order for Zoekt (Sourcegraph's search indexing backend)
# # to perform at scale without running into limitations.
sudo sh -c "echo 'fs.inotify.max_user_watches=128000' >> /etc/sysctl.conf"
sudo sh -c "echo 'vm.max_map_count=300000' >> /etc/sysctl.conf"
sudo sysctl --system # Reload configuration (no restart required.)

sudo sh -c "echo '* soft nproc 8192' >> /etc/security/limits.conf"
sudo sh -c "echo '* hard nproc 16384' >> /etc/security/limits.conf"
sudo sh -c "echo '* soft nofile 262144' >> /etc/security/limits.conf"
sudo sh -c "echo '* hard nofile 262144' >> /etc/security/limits.conf"

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
sleep 10 && k3s kubectl get node

# Correct permissions of k3s config file
sudo chown sourcegraph /etc/rancher/k3s/k3s.yaml
sudo chmod go-r /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'
cp /etc/rancher/k3s/k3s.yaml /home/sourcegraph/.kube/config

# k3s kubectl apply -f /home/sourcegraph/SetupWizard/redirect-page.yaml
###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# # Store Sourcegraph Helm charts locally
helm --kubeconfig /etc/rancher/k3s/k3s.yaml repo add sourcegraph https://helm.sourcegraph.com/release
helm --kubeconfig /etc/rancher/k3s/k3s.yaml pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph

# Add a cron job to format the data volume on next reboot
echo '@reboot sleep 10 && bash /home/sourcegraph/install.sh' | crontab -

# Add standard bash aliases
echo "export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "export INSTANCE_SIZE='$INSTANCE_SIZE'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "export SHELL='/bin/bash'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "alias k='kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile

# Generate files to save instance info in volumes for upgrade purpose
echo "$SOURCEGRAPH_VERSION" | sudo tee "$HOME/.sourcegraph-version"

# Ensure k3s stopped
sudo systemctl disable k3s
sudo systemctl stop k3s
sudo /usr/local/bin/k3s-killall.sh

# Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
# Symlink `/var/lib/kubelet` to `/mnt/data/kubelet`
sudo rm -rf /var/lib/kubelet
sudo ln -s /mnt/data/kubelet /var/lib/kubelet

# Put persistent volume pod storage in our data disk, and k3s's embedded database there too (it
# must be kept around in order for k3s to keep PVs attached to the right folder on disk if a node
# is lost (i.e. during an upgrade of Sourcegraph), see https://github.com/rancher/local-path-provisioner/issues/26
sudo rm -rf /var/lib/rancher/k3s/server/db
sudo ln -s /mnt/data/db /var/lib/rancher/k3s/server/db
sudo rm -rf /var/lib/rancher/k3s/storage
sudo ln -s /mnt/data/storage /var/lib/rancher/k3s/storage
exit 0
