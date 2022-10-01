#!/usr/bin/bash
##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
AMI_VERSION=$(cat /home/ec2-user/sourcegraph-version)
###############################################################################
# Delete ingress
/usr/local/bin/kubectl delete ingress sourcegraph-ingress
sudo systemctl restart k3s
# If k3s is not starting, reset it
if sudo systemctl status k3s.service | grep -q 'k3s.service failed'; then
    # Remove leftovers TLS certs and cred
    sudo rm -rf /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/
    sudo sh /usr/local/bin/k3s-killall.sh
fi
sleep 30
# Run install or upgrade
# TODO: B - Compare versions before performing upgrades
/usr/local/bin/helm upgrade --install --values /home/ec2-user/deploy/install/override.yaml --version "${AMI_VERSION}" sourcegraph /home/ec2-user/deploy/install/sourcegraph-"${AMI_VERSION}".tgz --kubeconfig /etc/rancher/k3s/k3s.yaml
# Create ingress
/usr/local/bin/kubectl create -f /home/ec2-user/deploy/install/ingress.yaml
sudo systemctl restart k3s
sleep 30
sudo systemctl restart k3s
sleep 120
