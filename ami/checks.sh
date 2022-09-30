#!/usr/bin/bash
# Script to keep track of AMI pipeline build status
set -exuo pipefail
DEPLOY_PATH='/home/ec2-user/deploy'
# Remove the status file on the second reboot during image building process
if [ -f "${DEPLOY_PATH}/.status.log" ]; then
    sudo rm "${DEPLOY_PATH}/.status.log"
else
    # Replace cron job with running the upgrade scripts on third start up
    echo "@reboot sleep 30 && bash ${DEPLOY_PATH}/install/reboot.sh" | crontab -
    # then reanble k3s and run the upgrade scripts
    sudo systemctl enable k3s
    sleep 10
    bash ${DEPLOY_PATH}/install/reboot.sh
fi
