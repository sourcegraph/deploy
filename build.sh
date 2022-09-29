#!/usr/bin/env bash
set -exuo pipefail

packer build -var-file=./packer/xs-m5a.hcl ./packer/sourcegraph.pkr.hcl
# TODO(slimsag): create subnet in this region, document how
#packer build -var-file=./packer/xs-m6a.hcl ./packer/sourcegraph.pkr.hcl
#packer build -var-file=./packer/s-m6a.hcl ./packer/sourcegraph.pkr.hcl
#packer build -var-file=./packer/m-m6a.hcl ./packer/sourcegraph.pkr.hcl
#packer build -var-file=./packer/l-m6a.hcl ./packer/sourcegraph.pkr.hcl
#packer build -var-file=./packer/xl-m6a.hcl ./packer/sourcegraph.pkr.hcl
