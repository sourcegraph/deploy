#!/usr/bin/env bash
set -exuo pipefail

# Configure kernel parameters. These must be set in order for Zoekt (Sourcegraph's search
# indexing backend) to perform at scale without running into limitations.
sudo sh -c "echo 'fs.inotify.max_user_watches=128000' >> /etc/sysctl.conf"
sudo sh -c "echo 'vm.max_map_count=300000' >> /etc/sysctl.conf"
sudo sysctl --system # Reload configuration (no restart required.)

# Ensure k3s cluster networking/DNS is allowed in local firewall.
# For details see: https://github.com/k3s-io/k3s/issues/24#issuecomment-469759329
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo iptables -I INPUT 1 -i cni0 -s 10.42.0.0/16 -j ACCEPT
sudo service iptables save

# Install k3s/kubernetes
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --cluster-cidr=10.10.0.0/16
sleep 10
k3s kubectl get node # Confirm our installation went ok

# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short

# TODO(slimsag): this needs to be persisted or something, without this `kubectl` is broken
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install local storage provisioner for k3s
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.22/deploy/local-path-storage.yaml
kubectl -n local-path-storage get pod

# Install Sourcegraph using Helm
helm upgrade --install --values ./override.yaml --version 3.43.1 sourcegraph sourcegraph/sourcegraph

# Create ingress
kubectl create -f ingress.yaml
