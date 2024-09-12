#!/usr/bin/env bash
set -exuo pipefail
###############################################################################
# curl -sfL https://raw.githubusercontent.com/sourcegraph/deploy/main/install/scripts/k3s/local.sh | bash
# Local version of a k3s instance will only launch with the smallest size, XS
###############################################################################
# e.g. 4.0.1, use the latest version if value is empty
INSTANCE_VERSION=${1:-''} # Default to empty
##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Variables
###############################################################################
SOURCEGRAPH_VERSION=$INSTANCE_VERSION
INSTANCE_USERNAME=$(whoami)
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy.git'
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
# If INSTANCE_VERSION is not empty, remove v
# e.g. v4.0.0 => 4.0.0
[ -n "$INSTANCE_VERSION" ] && INSTANCE_VERSION=${INSTANCE_VERSION#v}
###############################################################################
# Clone the deployment repository
###############################################################################
cd
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cp "$HOME/deploy/install/override.XS.yaml" "$HOME/deploy/install/override.yaml"
###############################################################################
# Install k3s (Kubernetes single-machine deployment)
###############################################################################
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.31.0+k3s1 K3S_TOKEN=none sh -s - \
  --node-name sourcegraph-0 \
  --write-kubeconfig-mode 644 \
  --cluster-cidr 10.10.0.0/16 \
  --kubelet-arg containerd=/run/k3s/containerd/containerd.sock \
  --etcd-expose-metrics true
# Confirm k3s and kubectl are up and running
sleep 5 && k3s kubectl get node
# Correct permissions of k3s config file
sudo chown "$INSTANCE_USERNAME" /etc/rancher/k3s/k3s.yaml
sudo chmod go-r /etc/rancher/k3s/k3s.yaml
# Set KUBECONFIG to point to k3s for 'kubectl' commands to work
export KUBECONFIG='/etc/rancher/k3s/k3s.yaml'
cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
###############################################################################
# Set up Sourcegraph using Helm
###############################################################################
# Install Helm
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short
# Store Sourcegraph Helm charts locally, rename the file to 'sourcegraph-charts.tgz'
helm --kubeconfig $KUBECONFIG_FILE repo add sourcegraph https://helm.sourcegraph.com/release
# Create override configMap for prometheus before startup Sourcegraph
k3s kubectl apply -f deploy/install/prometheus-override.ConfigMap.yaml
helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f "$HOME/deploy/install/override.yaml" --version "$SOURCEGRAPH_VERSION" sourcegraph sourcegraph/sourcegraph
sleep 5
helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f "$HOME/deploy/install/override.yaml" --version "$SOURCEGRAPH_VERSION" executor sourcegraph/sourcegraph-executor-k8s
k3s kubectl create -f deploy/install/ingress.yaml
