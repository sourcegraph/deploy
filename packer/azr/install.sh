#!/usr/bin/env bash
set -exuo pipefail

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Variables
###############################################################################
SOURCEGRAPH_VERSION=$INSTANCE_VERSION
SOURCEGRAPH_SIZE=$INSTANCE_SIZE
INSTANCE_USERNAME='sourcegraph'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'

###############################################################################
# If running as root, de-escalate to a regular user. The remainder of this script
# will always use `sudo` to indicate where root is required, so that it is clear
# what does and does not require root in our installation process.
###############################################################################
# If running as root, deescalate
if [ $UID -eq 0 ]; then
	cd /home/$INSTANCE_USERNAME
	chown $INSTANCE_USERNAME "$0" 
	exec su $INSTANCE_USERNAME "$0" -- "$@"
	# nothing will be executed beyond here (exec replaces the running process)
fi

###############################################################################
# Prepare the system
###############################################################################
sudo mv /tmp/reboot.sh /usr/local/bin/reboot.sh
sudo chown $INSTANCE_USERNAME /usr/local/bin/reboot.sh
mv /tmp/prometheus-override.ConfigMap.yaml /home/$INSTANCE_USERNAME/prometheus-override.ConfigMap.yaml
mv /tmp/override.yaml /home/$INSTANCE_USERNAME/override.yaml
mv /tmp/ingress.yaml /home/$INSTANCE_USERNAME/ingress.yaml

###############################################################################
# Configure EBS data volume
###############################################################################
# Format (if necessary) and mount the EBS volume
volume_device_name=$(readlink -f /dev/disk/azure/scsi1/lun0)
device_fs=$(sudo lsblk "$volume_device_name" --noheadings --output fsType)
if [ "$device_fs" == "" ]; then
    sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard "$volume_device_name"
    sudo e2label "$volume_device_name" /mnt/data
fi
sudo mkdir -p /mnt/data
sudo mount "$volume_device_name" /mnt/data

# Mount data disk on reboots by linking disk label to data root path
sudo echo "LABEL=/mnt/data  /mnt/data  ext4  discard,defaults,nofail  0  2" | sudo tee -a /etc/fstab
sudo umount /mnt/data
sudo mount -a

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
sudo apt-get update && sudo apt-get install -y iptables
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get install -y iptables-persistent
sudo iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo ip6tables-save | sudo tee /etc/iptables/rules.v6

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
sleep 5 && k3s kubectl get node

# Correct permissions of k3s config file
sudo chown $INSTANCE_USERNAME /etc/rancher/k3s/k3s.yaml
sudo chmod go-r /etc/rancher/k3s/k3s.yaml

# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'
cp /etc/rancher/k3s/k3s.yaml /home/$INSTANCE_USERNAME/.kube/config

# Add standard bash aliases
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | tee --append /home/$INSTANCE_USERNAME/.bash_profile
echo 'alias k="kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml"' | sudo tee --append /etc/bash.bashrc
echo 'alias h="helm --kubeconfig /etc/rancher/k3s/k3s.yaml"' | sudo tee --append /etc/bash.bashrc
echo 'alias sgupgrade="helm --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade -i -f /home/sourcegraph/deploy/install/override.yaml sourcegraph sourcegraph/sourcegraph"' | sudo tee --append /etc/bash.bashrc

###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# Store Sourcegraph Helm charts locally, rename the file to 'sourcegraph-charts.tgz'
helm --kubeconfig $KUBECONFIG_FILE repo add sourcegraph https://helm.sourcegraph.com/release
helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph
mv ./sourcegraph-"$SOURCEGRAPH_VERSION".tgz ./sourcegraph-charts.tgz

# Generate files to save instance info in volumes for upgrade purpose
echo "${SOURCEGRAPH_VERSION}" | sudo tee /home/$INSTANCE_USERNAME/.sourcegraph-version
echo "${SOURCEGRAPH_VERSION}-base" | sudo tee /mnt/data/.sourcegraph-version
echo "${SOURCEGRAPH_SIZE}" | sudo tee /home/$INSTANCE_USERNAME/.sourcegraph-size

# Create override configMap for prometheus before startup Sourcegraph
kubectl --kubeconfig $KUBECONFIG_FILE apply -f ./prometheus-override.ConfigMap.yaml
helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph ./sourcegraph-charts.tgz
# Skip ingress start-up during image creation step:
# kubectl --kubeconfig $KUBECONFIG_FILE create -f $DEPLOY_PATH/ingress.yaml

# Start Sourcegraph on next reboot
echo "@reboot sleep 10 && bash /usr/local/bin/reboot.sh" | crontab -

# Stop k3s and disable k3s to prevent it from starting on next reboot
sleep 180 # allows 3 mins for services to stand up before disabling k3s
sudo systemctl disable k3s
sudo systemctl stop k3s
