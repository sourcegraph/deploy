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
