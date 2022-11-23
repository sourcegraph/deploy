#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# ACTION REQUIRED IF RUNNING THIS SCRIPT MANUALLY
# IMPORTANT: Keep this commented when building with the packer pipeline
###############################################################################
INSTANCE_VERSION="" # e.g. 4.0.1
INSTANCE_SIZE="XS"  # e.g. XS / S / M / L / XL

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
git clone https://github.com/sourcegraph/SetupWizard.git
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

k3s kubectl apply -f /home/sourcegraph/SetupWizard/redirect-page.yaml
###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# # Store Sourcegraph Helm charts locally
helm --kubeconfig /etc/rancher/k3s/k3s.yaml repo add sourcegraph https://helm.sourcegraph.com/release
helm --kubeconfig /etc/rancher/k3s/k3s.yaml pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph

# Create override configMap for prometheus before startup Sourcegraph
k3s kubectl apply -f /home/sourcegraph/deploy/install/prometheus-override.ConfigMap.yaml

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

###############################################################################
# Build Sourcegraph Setup Wizard
###############################################################################
cd || exit
# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash -
sudo apt-get install -y nodejs nodejs
# Install bun.js
sudo apt-get install -y unzip
curl -sSL https://bun.sh/install | bash
export BUN_INSTALL=/home/sourcegraph/.bun
export PATH=/home/sourcegraph/.bun/bin:/home/sourcegraph/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
echo "export BUN_INSTALL='$HOME/.bun'" | tee -a "$HOME/.bashrc"
echo "export PATH='$BUN_INSTALL/bin:$PATH'" | tee -a "$HOME/.bashrc"
cd /home/sourcegraph/SetupWizard || exit
# Build wizard
bun install
bun run build --silent
sleep 5

sudo systemctl disable k3s
sudo systemctl stop k3s
exit 0
