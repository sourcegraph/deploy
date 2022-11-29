#!/usr/bin/bash

###############################################################################
# This scripts is for deploying Sourcegraph in a VM environment
# Customizable Variables
###############################################################################
INSTANCE_VERSION=${1:-''} # e.g. 4.0.1. Default to empty
INSTANCE_SIZE=${2:-'XS'}  # e.g. XS / S / M / L / XL. Default to XS
INSTALL_MODE=${3:-'all'}  # e.g all, volume, wizard.

###############################################################################
# IMPORTANT: FOR INTERNAL USE ONLY
# Interal Variables
###############################################################################
# Disable Wizard build by default until it is tested
SOURCEGRAPH_WIZARD_BUILDER='disable' # e.g. enable / disable the setup wizard
[ "$INSTALL_MODE" = "dev" ] && SOURCEGRAPH_WIZARD_BUILDER='enable'
# SOURCEGRAPH_IMAGE_BUILDER='' # Set this in packer to enable image build

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Default Variables
###############################################################################
# Make sure the v is removed from the version number
SOURCEGRAPH_VERSION=${INSTANCE_VERSION#v}
SOURCEGRAPH_SIZE=$INSTANCE_SIZE
VOLUME_DEVICE_NAME='/dev/sdb'
SOURCEGRAPH_DEPLOY_REPO_URL='https://github.com/sourcegraph/deploy'
DEPLOY_PATH="$HOME/deploy/install"
KUBECONFIG_FILE='/etc/rancher/k3s/k3s.yaml'
LOCAL_BIN_PATH='/usr/local/bin'
RANCHER_SERVER_PATH='/var/lib/rancher/k3s/server'
INSTANCE_BASEIMAGE=ubuntu
INSTANCE_USERNAME=sourcegraph
RUN_SCRIPTS=$INSTALL_MODE

###############################################################################
# Prepare the system user
# If running as root, de-escalate to a regular user. The remainder of this script
# will always use `sudo` to indicate where root is required, so that it is clear
# what does and does not require root in our installation process.
###############################################################################
# Check the base OS to set variables: Amazon Linux or Ubuntu LTS 22.04
cd || exit
if cat </etc/os-release | grep -q amzn; then
    INSTANCE_USERNAME=ec2-user
    INSTANCE_BASEIMAGE=amzn
    # If running as root, deescalate
    if [ $UID -eq 0 ]; then
        chown $INSTANCE_USERNAME "$0" # /var/lib/cloud/instance/scripts/part-001
        exec su $INSTANCE_USERNAME "$0" -- "$@"
        # nothing will be executed beyond here (exec replaces the running process)
    fi
fi

###############################################################################
# Prepare the system for deployment
###############################################################################
configure_system() {
    cd || exit
    # Install git, then clone the deployment repository
    if [ "$INSTANCE_BASEIMAGE" = 'ubuntu' ]; then
        sudo apt-get update -y
    else
        # Install git
        sudo yum update -y
        sudo yum install git -y
    fi
    # Clone the deployment repository
    [ ! -d "$HOME/deploy" ] && git clone $SOURCEGRAPH_DEPLOY_REPO_URL
    cp "$HOME/deploy/install/override.$SOURCEGRAPH_SIZE.yaml" "$HOME/deploy/install/override.yaml"
}

###############################################################################
# Kernel parameters required by Sourcegraph
###############################################################################
# These must be set in order for Zoekt (Sourcegraph's search indexing backend)
# to perform at scale without running into limitations.
configure_params() {
    sudo sh -c "echo 'fs.inotify.max_user_watches=128000' >> /etc/sysctl.conf"
    sudo sh -c "echo 'vm.max_map_count=300000' >> /etc/sysctl.conf"
    sudo sysctl --system # Reload configuration (no restart required.)
    sudo sh -c "echo '* soft nproc 8192' >> /etc/security/limits.conf"
    sudo sh -c "echo '* hard nproc 16384' >> /etc/security/limits.conf"
    sudo sh -c "echo '* soft nofile 262144' >> /etc/security/limits.conf"
    sudo sh -c "echo '* hard nofile 262144' >> /etc/security/limits.conf"
}

###############################################################################
# Configure data volumes for the Sourcegraph k3s instance
###############################################################################
configure_volumes() {
    # Create mounting directories for storing data from the Sourcegraph cluster
    sudo mkdir -p /mnt/data
    sudo mkdir -p /mnt/data/kubelet /var/lib/kubelet
    # If data volume is available and not mounted to /mnt/data
    if lsblk | grep -q "sdb" && ! lsblk | grep -q "/mnt/data"; then
        # Format (if necessary) and mount the data volume
        device_fs=$(sudo lsblk $VOLUME_DEVICE_NAME --noheadings --output fsType)
        if [ "$INSTANCE_BASEIMAGE" = 'ubuntu' ]; then
            if [ "$device_fs" == "" ]; then
                sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard $VOLUME_DEVICE_NAME
                sudo e2label $VOLUME_DEVICE_NAME /mnt/data # Add label to volume device
            fi
            sudo mount $VOLUME_DEVICE_NAME /mnt/data
            # Mount data disk on reboots by linking disk label to data root path
            sudo echo "LABEL=/mnt/data  /mnt/data  ext4  discard,defaults,nofail  0  2" | sudo tee -a /etc/fstab
        else
            if [ "$device_fs" == "" ]; then
                sudo mkfs -t xfs $VOLUME_DEVICE_NAME
                sudo xfs_admin -L /mnt/data $VOLUME_DEVICE_NAME # Add label to volume device
            fi
            sudo mount $VOLUME_DEVICE_NAME /mnt/data
            # Mount data disk on reboots by linking disk label to data root path
            sudo sh -c 'echo "LABEL=/mnt/data  /mnt/data  xfs  defaults,nofail  0  2" >> /etc/fstab'
        fi
        sudo umount /mnt/data
        sudo mount -a
        # Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
        if [ "$INSTANCE_BASEIMAGE" = 'ubuntu' ]; then
            sudo echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" | sudo tee -a /etc/fstab
        else
            sudo sh -c 'echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" >> /etc/fstab'
        fi
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
    fi
}

###############################################################################
# Install k3s (Kubernetes single-machine deployment)
###############################################################################
install_k3s() {
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
    cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
    # Add standard bash aliases
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' | tee -a "$HOME/.bash_profile"
    echo "alias k='kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a "$HOME/.bash_profile"
    echo "alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml'" | tee -a "$HOME/.bash_profile"
}

###############################################################################
# Build Sourcegraph Setup Wizard
# Either build with bun or next.js
###############################################################################
# Build with next.js
# Use nvm 14.16.0 to ensure it works on Ubuntu 18.04+ and Amazon Linux 2
start_wizard() {
    git clone https://github.com/sourcegraph/wizard.git
    # Set up ingress for the wizard with customized 404 page
    k3s kubectl apply -f "$HOME/wizard/wizard.yaml"
    # Patch the endpoint ip address with the hostname internal IP to expose the localhost service
    k3s kubectl patch endpoints wizard-ip --type merge --patch '{"subsets": [{"addresses": [{"ip": "'$(hostname -i)'"}],"ports": [{"name": "wizard","port": 30080,"protocol": "TCP"}]}]}'
    # Install Node.js
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
    . ~/.nvm/nvm.sh
    nvm install 14.16.0
    nvm use 14.16.0
    cd "$HOME/wizard" || exit
    npm install pm2 -g
    npm install
    npm run build
    sleep 10
    # Keep wizard running on restart
    pm2 start npm --name wizard -- start
    [ "$(whoami)" == 'sourcegraph' ] && sudo env PATH=$PATH:/home/sourcegraph/.nvm/versions/node/v14.16.0/bin /home/sourcegraph/.nvm/versions/node/v14.16.0/lib/node_modules/pm2/bin/pm2 startup systemd -u sourcegraph --hp /home/sourcegraph
    [ "$(whoami)" == 'ec2-user' ] && sudo env PATH=$PATH:/home/ec2-user/.nvm/versions/node/v14.16.0/bin /home/ec2-user/.nvm/versions/node/v14.16.0/lib/node_modules/pm2/bin/pm2 startup systemd -u ec2-user --hp /home/ec2-user
    pm2 save
}

build_wizard() {
    if [ "$SOURCEGRAPH_WIZARD_BUILDER" = "enable" ]; then
        cd || exit
        echo "Installing Setup Wizard"
        start_wizard
    fi
}

patch_wizard() {
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE patch endpoints wizard-ip --type merge --patch '{"subsets": [{"addresses": [{"ip": "'$(hostname -i)'"}],"ports": [{"name": "wizard","port": 30080,"protocol": "TCP"}]}]}'
}

###############################################################################
# Deploy Sourcegraph with Helm
###############################################################################
deploy_sg() {
    # Generate files to save instance info in volumes for upgrade purpose
    # First, pin the root image with the version number
    echo "$SOURCEGRAPH_VERSION" | sudo tee "$HOME/.sourcegraph-version"
    # Second, add version number to data volume
    # This is a new instance if /mnt/data/.sourcegraph-version doesn't exist in data volume
    if [ ! -f /mnt/data/.sourcegraph-version ]; then
        # So we will mark the version number with "base"
        # which will be removed on new deployment after reboot
        echo "base${SOURCEGRAPH_VERSION}" | sudo tee /mnt/data/.sourcegraph-version
    else
        # Else, if an existing data volume is attached, this is an upgrade
        echo "${SOURCEGRAPH_VERSION}" | sudo tee /mnt/data/.sourcegraph-version
    fi

    cd "$DEPLOY_PATH" || exit
    # Install Helm
    curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    helm version --short
    # Store Sourcegraph Helm charts locally, rename the file to 'sourcegraph-charts.tgz'
    helm --kubeconfig $KUBECONFIG_FILE repo add sourcegraph https://helm.sourcegraph.com/release
    helm --kubeconfig $KUBECONFIG_FILE pull --version "$SOURCEGRAPH_VERSION" sourcegraph/sourcegraph
    [ "$SOURCEGRAPH_VERSION" != "" ] && mv "$HOME/deploy/install/sourcegraph-$SOURCEGRAPH_VERSION.tgz" "$HOME/deploy/install/sourcegraph-charts.tgz"
    # Create override configMap for prometheus before startup Sourcegraph
    k3s kubectl apply -f "$HOME/deploy/install/prometheus-override.ConfigMap.yaml"
    # Deploy using local Helm Charts or remote Helm Charts
    if [ -f "$HOME/deploy/install/sourcegraph-charts.tgz" ]; then
        helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph "$HOME/deploy/install/sourcegraph-charts.tgz"
    else
        helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f ./override.yaml --version "$SOURCEGRAPH_VERSION" sourcegraph sourcegraph/sourcegraph
    fi

    # The Setup Wizard allows user to select their instance size that will
    # save the .sourcegraph-size to disk
    if [ "$SOURCEGRAPH_WIZARD_BUILDER" = "disable" ]; then
        echo "$SOURCEGRAPH_SIZE" | sudo tee "$HOME/.sourcegraph-size"
        k3s kubectl create -f "$HOME/deploy/install/ingress.yaml"
    fi
}

###############################################################################
# Preparing for image creation steps
###############################################################################
build_image() {
    # To enable this function, set SOURCEGRAPH_IMAGE_BUILDER in packer build
    if [ -n "$SOURCEGRAPH_IMAGE_BUILDER" ]; then
        # Skip ingress start-up during AMI creation step: k3s kubectl delete ing sourcegraph-ingress
        # Stop k3s and disable k3s to prevent it from starting on next reboot
        # allows 3 mins for services to stand up before disabling k3s
        sleep 120
        # Print to packer logs to confirm all the services and up
        kubectl --kubeconfig $KUBECONFIG_FILE get pods -A
        sudo systemctl disable k3s
        sudo systemctl stop k3s
        # Start Sourcegraph and k3s on next reboot
        echo "@reboot sleep 10;bash $HOME/install.sh v$SOURCEGRAPH_VERSION $SOURCEGRAPH_SIZE reboot >/dev/null 2>&1" | crontab -
    fi
}

###############################################################################
# REBOOT SCRIPTS COMPONENTS
###############################################################################
# Reset the containerd state if k3s is not starting
# NOTE: Cluster data will NOT be deleted
reset_k3s() {
    patch_wizard
    sudo systemctl restart k3s && sleep 30
    if ! sudo systemctl status k3s.service | grep -q 'active (running)'; then
        # Stop all of the K3s containers and reset the containerd state
        sudo sh $LOCAL_BIN_PATH/k3s-killall.sh
        # Remove leftovers TLS certs and cred
        sudo rm -rf $RANCHER_SERVER_PATH/cred/ $RANCHER_SERVER_PATH/tls/
        # Enable k3s in this cluster and start the unit now
        sudo systemctl enable --now k3s
    else
        # Delete any existing ingress from old instances before restarting k3s
        $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE delete ingress sourcegraph-ingress
    fi
    sudo systemctl restart k3s && sleep 30
}

# Install or upgrade Sourcegraph and create ingress
deploy_reboot() {
    AMI_VERSION=''
    [ -f "$HOME/.sourcegraph-version" ] && AMI_VERSION=$(cat "$HOME/.sourcegraph-version")
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE repo update
    $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE apply -f "$HOME/deploy/install/prometheus-override.ConfigMap.yaml"
    if [ -f ./sourcegraph-charts.tgz ]; then
        $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f "$HOME/deploy/install/override.yaml" --version "$AMI_VERSION" sourcegraph "$HOME/deploy/install/sourcegraph-charts.tgz"
    else
        $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE upgrade -i -f "$HOME/deploy/install/override.yaml" --version "$AMI_VERSION" sourcegraph sourcegraph/sourcegraph
    fi
    if ! $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE get ing | grep -q wizard-service; then
        $LOCAL_BIN_PATH/kubectl --kubeconfig $KUBECONFIG_FILE create -f "$HOME/deploy/install/ingress.yaml"
    fi
    echo "@reboot sleep 10 && sudo systemctl restart k3s && sleep 20 && bash $HOME/deploy/install/reboot.sh" | crontab -
    sleep 60 && sudo systemctl restart k3s
}

store_helm_version() {
    HELM_APP_VERSION=$(/usr/local/bin/helm --kubeconfig /etc/rancher/k3s/k3s.yaml history sourcegraph -o yaml --max 1 | grep 'app_version' | head -1 | cut -d ":" -f 2 | xargs)
    # Update version files if output is not empty
    [ -n "$HELM_APP_VERSION" ] && echo "$HELM_APP_VERSION" | sudo tee /mnt/data/.sourcegraph-version "$HOME/.sourcegraph-version"
    sleep 60 && sudo systemctl restart k3s
}

###############################################################################
# Check if this is a new instance or existing instance
###############################################################################
# Exit if AMI version is the same version as the volume
on_reboot() {
    sudo systemctl restart k3s
    if [ -f /mnt/data/.sourcegraph-version ]; then
        VOLUME_VERSION=$(cat /mnt/data/.sourcegraph-version)
        AMI_VERSION=$(cat "$HOME/.sourcegraph-version")
        if [ "$VOLUME_VERSION" = "$AMI_VERSION" ]; then
            sudo systemctl restart k3s
            # Make sure Setup Wizard is removed
            rm -rf wizard
            exit 0
        fi
    fi
    configure_volumes
    reset_k3s
    patch_wizard
    deploy_reboot
    store_helm_version
}

case $RUN_SCRIPTS in
volume)
    configure_volumes
    ;;
deploy)
    deploy_sg
    ;;
dev)
    configure_system
    configure_params
    configure_volumes
    install_k3s
    build_wizard
    deploy_sg
    build_image
    ;;
reboot)
    on_reboot
    ;;
install)
    install_k3s
    build_wizard
    deploy_sg
    ;;
wizard)
    build_wizard
    ;;
*)
    configure_system
    configure_params
    configure_volumes
    install_k3s
    deploy_sg
    build_image
    ;;
esac
