# Development

## Prerequisites

We use Hashicorp Packer to build images:

1. [Install Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/aws-get-started#installing-packer).
2. Run `packer init ./packer` at the root of this repository.
3. [Authenticate with AWS](https://www.packer.io/plugins/builders/amazon#authentication):
   * In AWS, select the username dropdown in the top right of the page and choose _User credentials_ to create an access key.
   * In your `~/.zshrc`, `~/.bash_profile`, etc. add:

```
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="yyy"
export AWS_DEFAULT_REGION="us-west-1"
```

## Project structure

* `doc/`: project documentation
* `install/`: installation scripts ran on a machine to turn it into a Sourcegraph deployment
  * `install.sh`: primary installation script ran on EC2 instance to turn it into a Sourcegraph deployment. Installs k3s, runs helm install, etc.
  * `ingress.yaml`: Kubernetes ingress controller configuration
  * `restart-k3s`: a cronjob script/hack to restart k3s on machine startup, in case IP address of machine changed.
  * `override.<size>.yaml`: The Helm override file we use for a given T-shirt size.
* `build.sh`: builds all AMIs and publishes to all supported regions
* `lint.sh`: run code formatters, validate Packer files, etc.

## Building an AMI

### A single AMI for testing

To build a single AMI for testing, create a new `packer/test.hcl` file based on an existing configuration such as `xs-m5a.hcl`. This file provides the configuration which is used by `packer/sourcegraph.pkr.hcl` to build the image. At the very least, you should change the `ami_name` field to indicate this is *your* test image (include your name in it.) Then run:

```
packer build -var-file=./packer/test.hcl ./packer/sourcegraph.pkr.hcl
```

### Publishing a release

1. Find-and-replace the last Sourcegraph version with the new version across this repo. For example:
   1. `3-0-0` -> `3-0-1`
   2. `--version 3.0.0` -> `--version 3.0.1`
   3. Be sure not to update markdown files by accident. If we need to release a new version of the AMIs _for the same Sourcegraph version we previously released_, then open all `<size>.hcl` files and update their `ami_name` fields from `rev1` to `rev2`.
2. Run `./build.sh` which will build all AMIs and copy them to the relevant regions.
3. Update README.md with the AMI IDs you just published.
4. Go to EC2 AMI console and look up the AMI using its `AMI ID`, and then select Actions > Edit AMI permissions > Public
5. Once the release is published, this repository is updated and all commits are merged, `git tag v4.0.0` and `git push origin v4.0.0` on the `main` branch.
6. Update the AWS AMI links in our [deployment docs](https://docs.sourcegraph.com/admin/deploy/aws-ami?).

### Creating a subnet in a new region

If adding a new region, you may need to create a subnet with the `Name` tag `packer-build` (Packer finds the subnet based on the name):

1. Navigate to the **Subnets**
2. **Create subnet**
3. **VPC**: default
4. **Subnet name**: packer-build
5. **IPv4 CIDR block**: 10.0.0.0/24
