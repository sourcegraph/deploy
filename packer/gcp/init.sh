#!/usr/bin/env bash
set -exuo pipefail

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
# Install git
sudo apt-get update -y
# sudo apt-get install -y git
# Clone the deployment repository
DEPLOY_PATH="$USER_ROOT_PATH/deploy/install"
cd $USER_ROOT_PATH
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cd $DEPLOY_PATH
cp override."$SOURCEGRAPH_SIZE".yaml override.yaml

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
# Configure network and volumes for k3s
###############################################################################
# Ensure k3s cluster networking/DNS is allowed in local firewall.
# For details see: https://github.com/k3s-io/k3s/issues/24#issuecomment-469759329
sudo apt-get update -y
sudo apt-get install -y iptables
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get -y install iptables-persistent
sudo iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6

###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# Add a cron job to format the data volume on next reboot
echo '@reboot sleep 10 && bash /home/sourcegraph/install.sh' | crontab -

# Add standard bash aliases
echo "export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "export INSTANCE_SIZE='$INSTANCE_SIZE'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "export SHELL='/bin/bash'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "alias k='kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a $USER_ROOT_PATH/.bash_profile
echo "alias sgupgrade='helm --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade -i -f /home/sourcegraph/deploy/install/override.yaml sourcegraph sourcegraph/sourcegraph'" | tee -a $USER_ROOT_PATH/.bash_profile

# Generate files to save instance info in volumes for upgrade purpose
echo "$SOURCEGRAPH_VERSION" | sudo tee $USER_ROOT_PATH/.sourcegraph-version
