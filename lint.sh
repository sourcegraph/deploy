#!/usr/bin/env bash
set -exuo pipefail

packer fmt -recursive -write .

packer validate --var-file=/packer/aws/aws-variables.hcl /packer/aws/aws-builder.pkr.hcl
packer validate --var-file=/packer/gcp/gcp-variables.hcl /packer/gcp/gcp-builder.pkr.hcl
