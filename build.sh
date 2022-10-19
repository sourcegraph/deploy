#!/usr/bin/env bash
set -exuo pipefail

# AWS AMI
packer build --var-file=./packer/build-variables.hcl ./packer/aws/aws-builder.pkr.hcl
# GCE Images
packer build --var-file=./packer/build-variables.hcl ./packer/gcp/gcp-builder.pkr.hcl
