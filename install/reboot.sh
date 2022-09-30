#!/usr/bin/bash
set -exuo pipefail

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
AMI_VERSION=$(cat /usr/local/bin/.sourcegraph-version)
HELM_APP_VERSION=$(/usr/local/bin/helm history sourcegraph -o yaml --kubeconfig /etc/rancher/k3s/k3s.yaml | grep 'pp_version' | cut -d ":" -f 2 | xargs)
VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
HELM_RELEASE_STATUS=$(/usr/local/bin/helm status sourcegraph --kubeconfig /etc/rancher/k3s/k3s.yaml | grep 'STATUS' | cut -d ":" -f 2 | xargs)
###############################################################################
# If k3s is not starting, reset it
if sudo systemctl status k3s.service | grep -q 'k3s.service failed'; then
    # Remove leftovers TLS certs and cred
    rm -rf /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/
    /usr/local/bin/k3s-killall.sh
else
    # Delete ingress
    /usr/local/bin/kubectl delete ingress sourcegraph-ingress
fi
sudo systemctl restart k3s
# If no .sourcegraph-version file in volume, that means they are on 4.0.0
[ ! -f "/mnt/data/.sourcegraph-version" ] && echo "4.0.0" >"/mnt/data/.sourcegraph-version"
# Run the upgrade / install if:
# 1. version number stored in volume has a "base" tag with the same version number
# 2. version number stored in volume is different than instance version number
if [ "${VOLUME_VERSION}" = "${AMI_VERSION}-base" ] || [ "${VOLUME_VERSION}" != "${AMI_VERSION}" ]; then
    /usr/local/bin/helm upgrade --install --values /home/ec2-user/deploy/install/override.yaml --version "${AMI_VERSION}" sourcegraph /home/ec2-user/deploy/install/sourcegraph-"${AMI_VERSION}".tgz --kubeconfig /etc/rancher/k3s/k3s.yaml
    sleep 10
    /usr/local/bin/kubectl create -f /home/ec2-user/deploy/install/ingress.yaml
fi
sleep 30
sudo systemctl restart k3s
sleep 30
# Check if the upgrade / install was successed before changing the stored version number
[ "${VOLUME_VERSION}" != "${AMI_VERSION}" ] &&
    # Update version file on disk if deployed sucessfully
    [ "${HELM_RELEASE_STATUS}" = "deployed" ] && [ "${HELM_APP_VERSION}" = "${AMI_VERSION}" ] && echo "${AMI_VERSION}" >"/mnt/data/.sourcegraph-version"
sudo systemctl restart k3s
