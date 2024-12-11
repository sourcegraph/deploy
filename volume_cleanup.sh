#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning up orphaned EBS volumes..."
aws ec2 describe-volumes \
  --filters Name=status,Values=available \
  --query 'Volumes[*].{ID:VolumeId}' \
  --output text |
  while read -r volume_id; do
    echo "Deleting volume $volume_id"
    aws ec2 delete-volume --volume-id "$volume_id"
  done
