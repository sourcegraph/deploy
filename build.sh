#!/usr/bin/env bash
set -exuo pipefail

packer build -var-file=./packer/xs-m5a.hcl ./packer/sourcegraph.pkr.hcl
# TODO(slimsag): create subnet in this region, document how
#packer build -var-file=./packer/xs-m6a.hcl ./packer/sourcegraph.pkr.hcl
