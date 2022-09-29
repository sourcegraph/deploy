#!/usr/bin/env bash
###############################################################################
# ACTION REQUIRED: REPLACE THE URL AND REVISION WITH YOUR DEPLOYMENT REPO INFO
###############################################################################
AMI_VERSION='4.0.1'
OVERRIDE_FILE='override.XS.yaml'
##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy.git'
DEPLOY_PATH='/home/ec2-user/deploy'
DATA_VOLUME_ROOT='/mnt/data'
EBS_VOLUME_DEVICE_NAME='/dev/sdb'
EBS_VOLUME_LABEL='/mnt/data'
KUBE_CONFIG='/etc/rancher/k3s/k3s.yaml'
set -euxo pipefail
# Install git
yum update -y
yum install git -y
# Clone the deployment repository
git clone "${SOURCEGRAPH_DEPLOY_REPO_URL}" "${DEPLOY_PATH}"
cd "${DEPLOY_PATH}"/install
cp "${OVERRIDE_FILE}" override.yaml
###############################################################################
# Configure EBS data volume
###############################################################################
# Format (if unformatted) and mount the EBS volume
device_fs=$(lsblk "${EBS_VOLUME_DEVICE_NAME}" --noheadings --output fsType)
if [ "${device_fs}" == "" ]; then
    mkfs -t xfs "${EBS_VOLUME_DEVICE_NAME}"
    xfs_admin -L "${EBS_VOLUME_LABEL}" "${EBS_VOLUME_DEVICE_NAME}"
fi
mkdir -p "${DATA_VOLUME_ROOT}"
mount -L "${EBS_VOLUME_LABEL}" "${DATA_VOLUME_ROOT}"
# Mount data disk on reboots by linking disk label to data root path
echo "LABEL=${EBS_VOLUME_LABEL}  ${DATA_VOLUME_ROOT}  xfs  defaults,nofail  0  2" >>'/etc/fstab'
umount "${DATA_VOLUME_ROOT}"
mount -a
###############################################################################
# Kernel parameters required by Sourcegraph
###############################################################################
# These must be set in order for Zoekt (Sourcegraph's search indexing backend)
# to perform at scale without running into limitations.
sh -c "echo 'fs.inotify.max_user_watches=128000' >> /etc/sysctl.conf"
sh -c "echo 'vm.max_map_count=300000' >> /etc/sysctl.conf"
sysctl --system # Reload configuration (no restart required.)
sh -c "echo '* soft nproc 8192' >> /etc/security/limits.conf"
sh -c "echo '* hard nproc 16384' >> /etc/security/limits.conf"
sh -c "echo '* soft nofile 262144' >> /etc/security/limits.conf"
sh -c "echo '* hard nofile 262144' >> /etc/security/limits.conf"
###############################################################################
# CONFIGURE NETWORK AND VOLUMES FOR K3S
###############################################################################
# Ensure k3s cluster networking/DNS is allowed in local firewall.
# For details see: https://github.com/k3s-io/k3s/issues/24#issuecomment-469759329
yum install iptables-services -y
systemctl enable iptables
systemctl start iptables
iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
service iptables save
# Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
mkdir -p /mnt/data/kubelet /var/lib/kubelet
sh -c 'echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" >> /etc/fstab'
mount -a
# Put persistent volume pod storage in our data disk, and k3s's embedded database there too (it
# must be kept around in order for k3s to keep PVs attached to the right folder on disk if a node
# is lost (i.e. during an upgrade of Sourcegraph), see https://github.com/rancher/local-path-provisioner/issues/26
mkdir -p /mnt/data/db
mkdir -p /var/lib/rancher/k3s/server
ln -s /mnt/data/db /var/lib/rancher/k3s/server/db
mkdir -p /mnt/data/storage
mkdir -p /var/lib/rancher/k3s
ln -s /mnt/data/storage /var/lib/rancher/k3s/storage
###############################################################################
# INSTALL K3S (Kubernetes single-machine deployment)
###############################################################################
# Install k3s/kubernetes
curl -sfL https://get.k3s.io | K3S_TOKEN=none sh -s - \
    --node-name sourcegraph-0 \
    --write-kubeconfig-mode 644 \
    --cluster-cidr=10.10.0.0/16
sleep 10
k3s kubectl get node # Confirm our installation went ok
# Correct permissions of k3s config file
chown ec2-user /etc/rancher/k3s/k3s.yaml
chmod go-r /etc/rancher/k3s/k3s.yaml
# Set KUBECONFIG to point to k3s, so that 'kubectl' command works.
export KUBECONFIG="${KUBE_CONFIG}"
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >>~/.bash_profile
{
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'
    echo 'alias k="kubectl"'
    echo 'alias cloudlog="sudo tail -f /var/log/cloud-init-output.log"'
} >>/home/ec2-user/.bash_profile
###############################################################################
# Install Sourcegraph using Helm into Kubernetes
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short
# Install Sourcegraph using Helm
helm repo add sourcegraph https://helm.sourcegraph.com/release
# Store charts locally
helm pull sourcegraph/sourcegraph
# helm upgrade --install --values ./override.yaml --version "${AMI_VERSION}" sourcegraph "${DEPLOY_PATH}"/install/sourcegraph-"${AMI_VERSION}".tgz --kubeconfig "${KUBE_CONFIG}"
[ ! -f "${DATA_VOLUME_ROOT}/.sourcegraph-version" ] && echo "${AMI_VERSION}-base" >"${DATA_VOLUME_ROOT}/.sourcegraph-version"
# Create ingress at ami initial start up
# Generate files to save current version in volumes for upgrade purpose
echo "${AMI_VERSION}" >"/home/ec2-user/.sourcegraph-version"
echo "@reboot sleep 10 && bash ${DEPLOY_PATH}/install/startup.sh" | crontab -
# Stop k3s after 5 minutes (or once everything is up)
sleep 300
systemctl stop k3s
