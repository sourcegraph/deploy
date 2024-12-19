# sourcegraph/deploy: one-click Sourcegraph deployments

**This repository is for Sourcegraph developers: for how to deploy Sourcegraph, please see [docs.sourcegraph.com](https://docs.sourcegraph.com)**

This repository is home of Sourcegraph one-click deployments (AMIs, VM images, etc.) distributed through various cloud providers.

## Overview

* [Development](./doc/development.md)
* [Debugging](./doc/debugging.md)
* [Manual AMI creation](./doc/manual-ami.md)
* [Official Docs](https://docs.sourcegraph.com/admin/deploy/machine-images)

## Instance size chart

We no longer provide dedicated images for each instance size. However, we suggest using our T-shirt sizes to estimate the size of instance you will need.

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users | 
|------|--------|--------------|-------------------|------------------|
| XS   | 500    | 1,000        | 5GB               | 100              |
| S    | 1,000  | 10,000       | 23GB              | 200              |
| M    | 5,000  | 50,000       | 23GB              | 1,000            |
| L    | 10,000 | 100,000      | 35GB              | 2,000            |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            |

## Sourcegraph AMI instance

Sourcegraph Amazon Machine Images (AMIs) allow you to quickly deploy a production-ready Sourcegraph instance tuned to your organization’s scale in just a few clicks.

A Sourcegraph AMI instance includes:
- A pre-configured Sourcegraph instance for your deployment
- A root EBS volume with 50GB of storage
- An additional EBS volume with 500GB of storage for storing code and search indices

### AWS Regions

Please reach out to us if you are not able to find Sourcegraph images for your region.

## Releases

See our [Releases](https://github.com/sourcegraph/deploy/releases) page for detailed information.

> NOTE: The default AMI username is `ec2-user`.
