#!/usr/bin/bash
###############################################################################
# ACTION REQUIRED: REPLACE THE URL AND REVISION WITH YOUR DEPLOYMENT REPO INFO
###############################################################################
AMI_VERSION='4.0.1'
##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
HELM_APP_VERSION=$(/usr/local/bin/helm history sourcegraph -o yaml --kubeconfig /etc/rancher/k3s/k3s.yaml | grep 'pp_version' | cut -d ":" -f 2 | xargs)
VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
HELM_RELEASE_STATUS=$(/usr/local/bin/helm status sourcegraph --kubeconfig /etc/rancher/k3s/k3s.yaml | grep 'STATUS' | cut -d ":" -f 2 | xargs)
# If k3s is not starting, reset it
if sudo systemctl status k3s.service | grep -q 'k3s.service failed'; then
    # Remove leftovers TLS certs and cred
    rm -rf /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/
    /usr/local/bin/k3s-killall.sh
else
    # Delete ingress
    /usr/local/bin/kubectl delete ingress sourcegraph-ingress
fi
systemctl restart k3s
sleep 15
if [ "${VOLUME_VERSION}" = "${AMI_VERSION}-base" ] || [ ! -f "${DATA_VOLUME_ROOT}/.sourcegraph-version" ]; then
    /usr/local/bin/helm upgrade --install --values /home/ec2-user/deploy/install/override.yaml --version 4.0.1 sourcegraph /home/ec2-user/deploy/install/sourcegraph-4.0.1.tgz --kubeconfig /etc/rancher/k3s/k3s.yaml
    /usr/local/bin/kubectl create -f /home/ec2-user/deploy/install/ingress.yaml
fi
sleep 30
sleep 30
systemctl restart k3s
# Run upgrades / install
[ "${VOLUME_VERSION}" != "${AMI_VERSION}" ] &&
    # Update version file on disk if deployed sucessfully
    [ "${HELM_RELEASE_STATUS}" = "deployed" ] && [ "${HELM_APP_VERSION}" = "${AMI_VERSION}" ] && echo "${AMI_VERSION}" >"/mnt/data/.sourcegraph-version"
