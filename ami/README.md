# Launch Scripts

This directory includes scripts that are used to generate instances our AMIs / AMI instances are based on.

## Overview

### Launch time

- Base-instance launch time: ~2 mins
- AMI-instance launch time:
  - Fresh instance: ~2 mins
  - Instance with existing volume: ~3 mins
    - Upgrade required: ~4 mins

### File Structure

- [./reboot.sh](reboot.sh)
  - A script for cron job to run on every reboot
  - It checks if safe to perform upgrades
- ./[launch.sh](launch.sh)
  - A script to put into `user data` when launching a base instance
  - It is only run ONCE when the instance is *FIRST* launched
- ./traefik-config.yaml - Not available
  - To be copy to `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml` inside the instance

## Instruction

### Manual Deployment

Below are the steps for base-instances and AMI creation:

1. Update the `AMI_VERSION` variable on line 5 in [launch script](launch.sh)
2. Follow the steps in our [Docker Compose deployment docs for AWS](https://docs.sourcegraph.com/admin/deploy/docker-compose/aws) to set up an AWS instance manually
   - replace the [startup scripts](https://docs.sourcegraph.com/admin/deploy/docker-compose/aws#advanced-details-user-data) with the [launch script](launch.sh) in this directory
3. After about 5-8 minutes, k3s will be stopped; however, the instance will still be accessible
4. You can now create an AMI off the running instance without stopping it
5. **Important:** Make sure to enable `No Reboot` when creating the AMI
