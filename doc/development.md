# Development

## Prerequisites

We use Hashicorp Packer to build images:

1. [Install Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli?in=packer/aws-get-started#installing-packer).
2. [Authenticate with AWS](https://www.packer.io/plugins/builders/amazon#authentication):
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
