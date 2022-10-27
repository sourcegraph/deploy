#!/usr/bin/env bash
set -exuo pipefail

###############################################################################
# Enable cgroup V1
###############################################################################
echo 'GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"' | sudo tee /etc/default/grub

sudo update-grub
sudo reboot