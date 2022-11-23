#!/usr/bin/env bash

###############################################################################
# This scripts is part of the steps for deploying Sourcegraph in a VM
# It is required when using an additional volume to store data from Sourcegraph
# Customizable Variables
###############################################################################
VOLUME_DEVICE_NAME='/dev/sdb'
SOURCEGRAPH_BASEIMAGE=ubuntu

##################### NO CHANGES REQUIRED BELOW THIS LINE #####################
# Default Variables
###############################################################################
# Check if the base OS to set variables: Amazon Linux or Ubuntu LTS 22.04
if cat </etc/os-release | grep -q amzn; then
    SOURCEGRAPH_BASEIMAGE=amzn
fi

###############################################################################
# Configure data volumes for the Sourcegraph k3s instance
###############################################################################
# Create mounting directories for storing data from the Sourcegraph cluster
sudo mkdir -p /mnt/data
sudo mkdir -p /mnt/data/kubelet /var/lib/kubelet

if ! lsblk | grep -q "sdb"; then
    # Format (if necessary) and mount the data volume
    if [ "$SOURCEGRAPH_BASEIMAGE" = 'ubuntu' ]; then
        device_fs=$(sudo lsblk $VOLUME_DEVICE_NAME --noheadings --output fsType)
        if [ "$device_fs" == "" ]; then
            sudo mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard $VOLUME_DEVICE_NAME
            sudo e2label $VOLUME_DEVICE_NAME /mnt/data # Add label to volume device
        fi
        sudo mount $VOLUME_DEVICE_NAME /mnt/data
        # Mount data disk on reboots by linking disk label to data root path
        sudo echo "LABEL=/mnt/data  /mnt/data  ext4  discard,defaults,nofail  0  2" | sudo tee -a /etc/fstab
    else
        device_fs=$(sudo lsblk $VOLUME_DEVICE_NAME --noheadings --output fsType)
        if [ "$device_fs" == "" ]; then
            sudo mkfs -t xfs $VOLUME_DEVICE_NAME
            sudo xfs_admin -L /mnt/data $VOLUME_DEVICE_NAME
        fi
        sudo mount $VOLUME_DEVICE_NAME /mnt/data
        # Mount data disk on reboots by linking disk label to data root path
        sudo sh -c 'echo "LABEL=/mnt/data  /mnt/data  xfs  defaults,nofail  0  2" >> /etc/fstab'
    fi
    sudo umount /mnt/data
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
    # Put ephemeral kubelet/pod storage in our data disk (since it is the only large disk we have.)
    if [ "$SOURCEGRAPH_BASEIMAGE" = 'ubuntu' ]; then
        sudo echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" | sudo tee -a /etc/fstab
    else
        sudo sh -c 'echo "/mnt/data/kubelet    /var/lib/kubelet    none    bind" >> /etc/fstab'
    fi
fi
