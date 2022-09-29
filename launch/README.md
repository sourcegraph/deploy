# Launch Scripts

The scripts in this directory are designed to use for launching base instances which our AMIs are based on.

## Explain

### File Structure

- ./install.sh
  - A script for cron job to run on every reboot
  - It checks if safe to perform upgrades
- ./user-data.sh
  - A script to put into `user data` when launching a base instance
  - It is only run ONCE when the instance is FIRST launched

## Instruction

Below are the steps for base-instances and AMI creation:

1. Update the `AMI_VERSION` variable on line 5 in both files
2. Follow the steps in our [Docker Compose deployment docs for AWS](https://docs.sourcegraph.com/admin/deploy/docker-compose/aws) to set up an AWS instance manually
   - replace the [startup scripts](https://docs.sourcegraph.com/admin/deploy/docker-compose/aws#advanced-details-user-data) with the [user-data.sh script](user-data.sh) in this directory
3. After about 5-8 minutes, k3s will be stopped; however, the instance will still be accessible
4. You can now create an AMI off the running instance without stopping it
5. **Important:** Make sure to enable `No Reboot` when creating the AMI


## Helpful commands

```bash
# Stop k3s
systemctl stop k3s
# Kill k3s
bash /usr/local/bin/k3s-killall.sh
# Remove tls certs and creds
rm -rf /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/
```
