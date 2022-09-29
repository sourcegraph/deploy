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
