#!/usr/bin/env bash
set -exuo pipefail

packer fmt -recursive -write .

packer validate --var-file=./packer/build-variables.hcl /packer/aws/aws-builder.pkr.hcl
packer validate --var-file=./packer/build-variables.hcl /packer/gcp/gcp-builder.pkr.hcl
