# Installing a Sourcegraph K3s Instance

## Prerequisite

- The base OS image or VM environment must be either Amazon Linux 2 or Ubuntu LTS 22.04 to use the provided scripts.
- Resources available for your instance size

### Notes

The scripts should technically work on other Linux OS, but additional changes might be required and currently not supported officially.

If you would like to deploy a production-ready Sourcegraph instance to your VM and is running into issues while deploying with the provided scripts, please reach out to our support team directly for further assists.

## Overview

Here are the steps to deploy a single-node Sourcegraph instance that is production-ready:

1. Prepare the system
   1. System User
      1. Run as non-root
      2. Username should be `sourcegraph` for Ubuntu OS and `ec2-user` for Amazon Linux
   2. Prepare the system for deployment
      1. Install git
      2. Clone the deployment repository
      3. Prepare the override.yaml file based on selected instance size for deployment purpose
   3. Configure kernel parameters required by Sourcegraph
      1. These must be set in order for Zoekt (Sourcegraph's search indexing backend) to perform at scale without running into limitations
2. Configure data volumes for the deployment
   1. Create mounting directories for storing data from the Sourcegraph cluster
   2. Format the non-root data volume if necessary
   3. Label the non-root data volume for identification purpose
      1. When redeploying Sourcegraph using a new image with an exisiting volume, the new image system will look for this specified label `mnt/data` to mount the data volume automatically
   4. Configure to mount data disk on reboot
   5. Put k3s's embedded database in our data disk
      1. This is required for k3s to keep PVs attached to the right folder on disk if a node is lost (i.e. during an upgrade)
   6. Put persistent volume pod storage in our data disk
3. Deploy Sourcegraph
   1. Install k3s (Kubernetes single-machine deployment)
      1. Set node-name to `sourcegraph-0`
      2. Correct the permissions of k3s's kubeconfig file `/etc/rancher/k3s/k3s.yaml` for the VM user
      3. Move the new kubeconfig file `/etc/rancher/k3s/k3s.yaml` to the `.kube` config directory
      4. Add standard bash aliases
   2. Set up the `Sourcegraph Setup Wizard`
   3. Deploy Sourcegraph with Helm
      1. Install Helm
      2. Download Sourcegraph Helm Charts if setting up as a version-specified instance
      3. Add the prometheus-override.ConfigMap file created for Sourcegraph k3s instances
      4. Create ingress for Sourcegraph
4. For internal image creation only: Stop and disable k3s to prevent it from starting right away on next reboot

## Scripts

### install.sh

Our main deployment script is [install.sh](../install.sh). It is the scripts we use to build our Machine Images.

It performs all the steps listed in the overview section above to set up a Sourcegraph instance in a K3s cluster on a linux machine.

### Components

Our main deployment script can be divided into three different sub-scripts (components) for different needs:

1. volume.sh
2. deploy.sh
3. wizard.sh

> NOTE: Each script starts with setting up variables for the installation process

#### volume.sh

The `volume.sh` script is for configuring your data volume with the correct volumes mounting and discovering stretegy for a Sourcegraph K3s instance as listed in the `Configure data volumes for the deployment` step above.

It should be run **first** to prepare your instance if you are using an additional data volume to store cluster data, including your repositories.

#### deploy.sh

The `deploy.sh` script is for deploying a Sourcegraph k3s instance on the machine as listed in the `Deploy Sourcegraph` step above.

Use this script only if you are deploying Sourcegraph on a personal machine (Linux only) without needing to store the cluster data externally.

#### wizard.sh

The `wizard.sh` script is for launching the Sourcegraph Image Instance Setup Wizard, which is a setup assistant built for configuring a Sourcegraph machine image instance from UI. It is part of the `Deploy Sourcegraph` step.
