#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# This scripts is for deploying Sourcegraph in a VM environment
# Customizable Variables
###############################################################################
# ACTION REQUIRED IF RUNNING THIS SCRIPT MANUALLY
# IMPORTANT: Keep this commented when building with the packer pipeline
INSTANCE_VERSION="" # e.g. 4.0.1
INSTANCE_SIZE="XS"  # e.g. XS / S / M / L / XL

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Default Variables
###############################################################################
SOURCEGRAPH_VERSION=$INSTANCE_VERSION
SOURCEGRAPH_SIZE=$INSTANCE_SIZE
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy'
DEPLOY_PATH="$HOME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
INSTANCE_BASEIMAGE=ubuntu
INSTANCE_USERNAME=sourcegraph
# Make sure the v is removed from the version number
[ -n "$INSTANCE_VERSION" ] && INSTANCE_VERSION=${INSTANCE_VERSION#v}
###############################################################################
# Prepare the system user
# If running as root, de-escalate to a regular user. The remainder of this script
# will always use `sudo` to indicate where root is required, so that it is clear
# what does and does not require root in our installation process.
###############################################################################
# Check the base OS to set variables: Amazon Linux or Ubuntu LTS 22.04
if cat </etc/os-release | grep -q amzn; then
    INSTANCE_USERNAME=ec2-user
    INSTANCE_BASEIMAGE=amzn
fi
# If running as root, deescalate
if [ $UID -eq 0 ]; then
    INSTANCE_USERNAME=ec2-user
    cd /home/$INSTANCE_USERNAME
    chown $INSTANCE_USERNAME "$0" # /var/lib/cloud/instance/scripts/part-001
    exec su $INSTANCE_USERNAME "$0" -- "$@"
    # nothing will be executed beyond here (exec replaces the running process)
fi

###############################################################################
# Prepare the system for deployment
###############################################################################
cd
# Install git, then clone the Setup Wizard repository
if [ "$INSTANCE_BASEIMAGE" = 'ubuntu' ]; then
    sudo apt-get update -y
else
    # Install git
    sudo yum update -y
    sudo yum install git -y
fi
# Clone the deployment repository
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cd "$DEPLOY_PATH"
cp override.$SOURCEGRAPH_SIZE.yaml override.yaml

###############################################################################
# Kernel parameters required by Sourcegraph
###############################################################################
# These must be set in order for Zoekt (Sourcegraph's search indexing backend)
# to perform at scale without running into limitations.
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
sleep 5 && k3s kubectl get node
# Correct permissions of k3s config file
sudo chown $INSTANCE_USERNAME /etc/rancher/k3s/k3s.yaml
sudo chmod go-r /etc/rancher/k3s/k3s.yaml
# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'
cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
# Add standard bash aliases
echo export KUBECONFIG=/etc/rancher/k3s/k3s.yaml | tee -a "$HOME/.bash_profile"
echo alias k="k3s kubectl" | tee -a "$HOME/.bash_profile"
echo alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml' | tee -a "$HOME/.bash_profile"

###############################################################################
# Deploy Sourcegraph with Helm
###############################################################################
cd "$DEPLOY_PATH" || exit
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short
# Store Sourcegraph Helm charts locally, rename the file to 'sourcegraph-charts.tgz'
helm --kubeconfig $KUBECONFIG_FILE repo add sourcegraph https://helm.sourcegraph.com/release
helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph
[ "$SOURCEGRAPH_VERSION" != "" ] && mv "$HOME/deploy/install/sourcegraph-$SOURCEGRAPH_VERSION.tgz" "$HOME/deploy/install/sourcegraph-charts.tgz"
# Create override configMap for prometheus before startup Sourcegraph
k3s kubectl apply -f "$HOME/deploy/install/prometheus-override.ConfigMap.yaml"
# Deploy using local Helm Charts or remote Helm Charts
if [ -f "$HOME/deploy/install/sourcegraph-charts.tgz" ]; then
    helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph "$HOME/deploy/install/sourcegraph-charts.tgz"
else
    helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph sourcegraph/sourcegraph
fi

# Generate files to save instance info in volumes for upgrade purpose
echo "$SOURCEGRAPH_VERSION" | sudo tee "$HOME/.sourcegraph-version"
echo "${SOURCEGRAPH_VERSION}-base" | sudo tee /mnt/data/.sourcegraph-version

# The Setup Wizard allows user to select their instance size that will
# save the .sourcegraph-size to disk
if [ ! -d "$HOME/SetupWizard" ]; then
    echo "$SOURCEGRAPH_SIZE" | sudo tee "$HOME/.sourcegraph-size"
    k3s kubectl create -f "$HOME/deploy/install/ingress.yaml"
fi
sleep 30
k3s kubectl get pods -A
exit 0
