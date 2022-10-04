# sourcegraph/deploy: one-click Sourcegraph deployments

**This repository is for Sourcegraph developers: for how to deploy Sourcegraph, please see [docs.sourcegraph.com](https://docs.sourcegraph.com)**

This repository is home of Sourcegraph one-click deployments (AMIs, VM images, etc.) distributed through various cloud providers.

## Overview

* [Development](./doc/development.md)
* [Debugging](./doc/debugging.md)
* [Manual AMI creation](./doc/manual-ami.md)

## Sourcegraph AMI instance

Sourcegraph Amazon Machine Images (AMIs) allow you to quickly deploy a production-ready Sourcegraph instance tuned to your organization’s scale in just a few clicks.

A Sourcegraph AMI instance includes:
- A pre-configured Sourcegraph instance for your deployment
- A root EBS volume with 50GB of storage
- An additional EBS volume with 500GB of storage for storing code and search indices

## T-shirt sizing

We use T-shirt sizes which are [load tested with specific configurations](https://github.com/sourcegraph/reference-architecture-test).

To create an AMI for the given T-shirt size, follow the steps and reference this table:

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users | Instance type | Storage   | IOPS    |
| ---- | ------ | ------------ | ----------------- | ---------------- | ------------- | --------- | ------- |
| XS   | 00,500 | 1,000        | 5GB               | 100              | m6a.2xlarge   | gp3       | default |
| S    | 01,000 | 10,000       | 23GB              | 200              | m6a.4xlarge   | gp3       | default |
| M    | 05,000 | 50,000       | 23GB              | 1,000            | m6a.8xlarge   | gp3       | default |
| L    | 10,000 | 100,000      | 35GB              | 2,000            | m6a.12xlarge  | io2       | 16,000  |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            | m6a.24xlarge  | io2       | 16,000  |

## Releases

### Amazon EC2 AMIs

See [CHANGLOG.md](CHANGELOG.md) for the completed list.

> NOTE: The default AMI user name is `**ec2-user**`.