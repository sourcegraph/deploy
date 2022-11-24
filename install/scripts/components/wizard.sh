#!/usr/bin/env bash

INSTANCE_SIZE=${1:-'XS'} # e.g. XS / S / M / L / XL. Default to XS

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Variables
###############################################################################
SOURCEGRAPH_SIZE=$INSTANCE_SIZE
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy.git'
SOURCEGRAPH_BASEIMAGE=ubuntu
# Check if the base OS to set variables: Amazon Linux or Ubuntu LTS 22.04
if cat </etc/os-release | grep -q amzn; then
    SOURCEGRAPH_BASEIMAGE=amzn
fi

###############################################################################
# Prepare the system
###############################################################################
cd || exit
# Install git, then clone the Setup Wizard repository
if [ "$SOURCEGRAPH_BASEIMAGE" = 'ubuntu' ]; then
    sudo apt-get update -y
else
    sudo yum update -y
    sudo yum install git -y
fi

# Clone the deployment repository
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cp "$HOME/deploy/install/override.$SOURCEGRAPH_SIZE.yaml" "$HOME/deploy/install/override.yaml"

###############################################################################
# Build Sourcegraph Setup Wizard
###############################################################################
cd || exit
git clone https://github.com/sourcegraph/wizard.git
# Set up ingress for the wizard with customized 404 page
k3s kubectl apply -f "$HOME/wizard/wizard.yaml"
# Patch the endpoint ip address with the hostname internal IP to expose the localhost service
k3s kubectl patch endpoints wizard-ip --type merge --patch '{"subsets": [{"addresses": [{"ip": "'$(hostname -i)'"}],"ports": [{"name": "wizard","port": 30080,"protocol": "TCP"}]}]}'
# Install Node.js
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
nvm install 14.16.0
nvm use 14.16.0
cd "$HOME/wizard" || exit
npm install
npm run build
(npm run start &)

exit 0
