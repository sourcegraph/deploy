#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# ACTION REQUIRED IF BUILDING MANUALLY
###############################################################################
SOURCEGRAPH_VERSION="${INSTANCE_VERSION}" # e.g. "4.0.1"
AMI_SIZE="${INSTANCE_SIZE}" # XS, S, M, L, etc.
##################### NO CHANGES REQUIRED BELOW THIS LINE #####################

###############################################################################
# Variables
###############################################################################
EBS_VOLUME_DEVICE_NAME='/dev/nvme1n1'
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy.git'
DEPLOY_PATH='/home/ec2-user/deploy'

###############################################################################
# Prepare the system
###############################################################################
# Install git
yum update -y
yum install git -y

# Clone the deployment repository
git clone "${SOURCEGRAPH_DEPLOY_REPO_URL}" "${DEPLOY_PATH}"
cd "${DEPLOY_PATH}"/ami
cp override."${AMI_SIZE}".yaml override.yaml

###############################################################################
# Configure EBS data volume
###############################################################################

# Format (if necessary) and mount the EBS volume
device_fs=$(lsblk "${EBS_VOLUME_DEVICE_NAME}" --noheadings --output fsType)
if [ "${device_fs}" == "" ]; then
	sudo mkfs -t xfs "${EBS_VOLUME_DEVICE_NAME}"
	sudo xfs_admin -L /mnt/data "${EBS_VOLUME_DEVICE_NAME}"
fi
sudo mkdir -p /mnt/data
sudo mount "${EBS_VOLUME_DEVICE_NAME}" /mnt/data

# Mount data disk on reboots by linking disk label to data root path
sudo sh -c 'echo "LABEL=/mnt/data  /mnt/data  xfs  defaults,nofail  0  2" >> /etc/fstab'
sudo umount /mnt/data
sudo mount -a

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
# Configure network and volumes for k3s
###############################################################################
# Ensure k3s cluster networking/DNS is allowed in local firewall.
# For details see: https://github.com/k3s-io/k3s/issues/24#issuecomment-469759329
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
sudo service iptables save

# Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
sudo mkdir -p /mnt/data/kubelet /var/lib/kubelet
sudo sh -c 'echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" >> /etc/fstab'
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
	--cluster-cidr=10.10.0.0/16

sleep 10
k3s kubectl get node # Confirm our installation went ok

# Correct permissions of k3s config file
sudo chown ec2-user /etc/rancher/k3s/k3s.yaml
chmod go-r /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG to point to k3s, so that 'kubectl' command works.
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >>~/.bash_profile

# Add standard bash aliases
{
	echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'
	echo 'alias k="kubectl"'
	echo 'alias cloudlog="sudo tail -f /var/log/cloud-init-output.log"'
} >>/home/ec2-user/.bash_profile

###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# Store Sourcegraph Helm charts locally
helm repo add sourcegraph https://helm.sourcegraph.com/release
helm pull sourcegraph/sourcegraph

# Install helm chart at ami initial start up
# helm upgrade --install --values ./override.yaml --version "${SOURCEGRAPH_VERSION}" sourcegraph "${DEPLOY_PATH}"/ami/sourcegraph-"${SOURCEGRAPH_VERSION}".tgz --kubeconfig "${KUBE_CONFIG}"
[ ! -f "/mnt/data/.sourcegraph-version" ] && echo "${SOURCEGRAPH_VERSION}-base" >"/mnt/data/.sourcegraph-version"

# Generate files to save current version in volumes for upgrade purpose
echo "${AMI_VERSION}" >"/home/ec2-user/.sourcegraph-version"
echo "@reboot sleep 10 && bash ${DEPLOY_PATH}/ami/reboot.sh" | crontab -

# Create ingress at ami initial start up
# Stop k3s after 5 minutes (or once everything is up)
sleep 300
systemctl stop k3s
