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
    git clone https://github.com/sourcegraph/SetupWizard.git
else
    sudo yum update -y
    sudo yum install git -y
    git clone https://github.com/sourcegraph/wizard.git
fi

# Clone the deployment repository
git clone $SOURCEGRAPH_DEPLOY_REPO_URL
cp "$HOME/deploy/install/override.$SOURCEGRAPH_SIZE.yaml" "$HOME/deploy/install/override.yaml"

###############################################################################
# Build Sourcegraph Setup Wizard
###############################################################################
cd || exit
# We can only install bun on ubuntu LTS 22.04+
if [ "$SOURCEGRAPH_BASEIMAGE" = 'ubuntu' ]; then
    k3s kubectl apply -f "$HOME/SetupWizard/redirect-page.yaml"
    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_19.x | sudo -E bash -
    sudo apt-get install -y nodejs nodejs
    # Install bun.js
    sudo apt-get install -y unzip
    curl -sSL https://bun.sh/install | bash
    export BUN_INSTALL=$HOME/.bun
    export PATH=$HOME/.bun/bin:$HOME/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
    echo "export BUN_INSTALL=$HOME/.bun" | tee -a "$HOME/.bashrc"
    echo "export PATH=$HOME/.bun/bin:$HOME/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin" | tee -a "$HOME/.bashrc"
    cd "$HOME/SetupWizard" || exit
    # Build wizard
    bun install
    bun run build --silent
else
    XIP=$(curl https://ipinfo.io/ip)
    echo $XIP
    k3s kubectl apply -f "$HOME/wizard/wizard.yaml"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
    . $HOME/.nvm/nvm.sh
    nvm install 14.16.0
    nvm use 14.16.0
    cd "$HOME/wizard"
    npm install
    npm run build
    (npm run start &)

    sudo iptables -A INPUT -i eth0 -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -i eth0 -p tcp --dport 30080 -j ACCEPT
    sudo iptables -A PREROUTING -t nat -i eth0 -p tcp --dport 80 -j REDIRECT --to-port 30080
    kubectl patch endpoints minikube-host --patch '{"subsets": [{"addresses": [{"ip": "'$(minikube ssh 'grep host.minikube.internal /etc/hosts | cut -f1' | tr -d '[:space:]')'"}]}]}'
fi
exit 0
