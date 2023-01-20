#!/bin/bash

set -euf -o pipefail

### Install packer



### Setup packer env
packer init --var-file=../packer/dev/dev-variables.hcl ../packer/dev/dev-builder.pkr.hcl
packer init --var-file=../packer/build-variables.hcl ../packer/aws/aws-builder.pkr.hcl
packer init --var-file=../packer/build-variables.hcl ../packer/aws-latest/aws-builder.pkr.hcl
packer init --var-file=../packer/build-variables.hcl ../packer/gcp/gcp-builder.pkr.hcl

echo 'ran the command!'
