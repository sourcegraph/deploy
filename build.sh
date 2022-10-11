#!/usr/bin/env bash
set -exuo pipefail

packer build --var-file=./packer/aws/aws-variables.hcl ./packer/aws/aws-builder.pkr.hcl
packer build --var-file=./packer/gcp/gcp-variables.hcl ./packer/gcp/gcp-builder.pkr.hcl
