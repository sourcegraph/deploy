#!/usr/bin/env bash
set -exuo pipefail
​
###############################################################################
# Configure EBS data volume
###############################################################################
EBS_VOLUME_DEVICE_NAME='/dev/nvme1n1'
​
# Format (if necessary) and mount EBS volume
device_fs=$(lsblk "${EBS_VOLUME_DEVICE_NAME}" --noheadings --output fsType)
if [ "${device_fs}" == "" ]; then ## only format the volume if it isn't already formatted
	sudo mkfs -t xfs "${EBS_VOLUME_DEVICE_NAME}"
	sudo xfs_admin -L '/mnt/data' "${EBS_VOLUME_DEVICE_NAME}"
fi
sudo mkdir -p /mnt/data
sudo mount "${EBS_VOLUME_DEVICE_NAME}" /mnt/data
​
# Mount EBS volume on reboots
sudo sh -c 'echo "LABEL=/mnt/data  /mnt/data  xfs  defaults,nofail  0  2" >> /etc/fstab'
sudo umount /mnt/data
sudo mount -a
​
###############################################################################
# Kernel parameters required by Sourcegraph
###############################################################################
# These must be set in order for Zoekt (Sourcegraph's search indexing backend)
# to perform at scale without running into limitations.
sudo sh -c "echo 'fs.inotify.max_user_watches=128000' >> /etc/sysctl.conf"
sudo sh -c "echo 'vm.max_map_count=300000' >> /etc/sysctl.conf"
sudo sysctl --system # Reload configuration (no restart required.)
​
###############################################################################
# Install k3s (Kubernetes single-machine deployment)
###############################################################################
# Ensure k3s cluster networking/DNS is allowed in local firewall.
# For details see: https://github.com/k3s-io/k3s/issues/24#issuecomment-469759329
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
sudo service iptables save
​
# Put ephemeral pod storage in our data disk (since it is the only large disk we have.)
sudo mkdir -p /mnt/data/ephemeral
sudo ln -s /mnt/data/ephemeral /var/lib/kubelet
​
# Install k3s/kubernetes
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --cluster-cidr=10.10.0.0/16
sleep 10
k3s kubectl get node # Confirm our installation went ok
​
# Correct permissions of k3s config file
sudo chown ec2-user /etc/rancher/k3s/k3s.yaml
chmod go-r /etc/rancher/k3s/k3s.yaml
​
# Set KUBECONFIG to point to k3s, so that 'kubectl' command works.
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >>~/.bash_profile
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
​
###############################################################################
# Install Sourcegraph using Helm into Kubernetes
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short
​
# Install local storage provisioner for k3s
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.22/deploy/local-path-storage.yaml
sleep 5
kubectl -n local-path-storage get pod
kubectl apply -f local-path-provisioner.ConfigMap.yaml
echo "Waiting for local path provisioner to pick up new configuration.."
sleep 30
​
# Install Sourcegraph using Helm
helm repo add sourcegraph https://helm.sourcegraph.com/release
helm upgrade --install --values ./override.yaml --version 3.43.1 sourcegraph sourcegraph/sourcegraph
​
# Create ingress
kubectl create -f ingress.yaml
