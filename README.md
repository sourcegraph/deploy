# sourcegraph/deploy: one-click Sourcegraph deployments

**This repository is for Sourcegraph developers: for how to deploy Sourcegraph, please see [docs.sourcegraph.com](https://docs.sourcegraph.com)**

This repository is home of Sourcegraph one-click deployments (AMIs, VM images, etc.) distributed through various cloud providers.

# Overview

* [Development](./doc/development.md)
* [Debugging](./doc/debugging.md)
* [Manual AMI creation](./doc/manual-ami.md)

## T-shirt sizing

We use T-shirt sizes which are [load tested with specific configurations](https://github.com/sourcegraph/reference-architecture-test).

To create an AMI for the given T-shirt size, follow the steps and reference this table:

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users | Instance type | Storage   | IOPS   |
| ---- | ------ | ------------ | ----------------- | ---------------- | ------------- | --------- | ------ |
| XS   | 00,500 | 1,000        | 5GB               | 100              | m6a.2xlarge   | gp3       |        |
| S    | 01,000 | 10,000       | 23GB              | 200              | m6a.4xlarge   | gp3       |        |
| M    | 05,000 | 50,000       | 23GB              | 1,000            | m6a.8xlarge   | gp3       |        |
| L    | 10,000 | 100,000      | 35GB              | 2,000            | m6a.12xlarge  | io2       | 16,000 |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            | m6a.24xlarge  | io2       | 16,000 |
| 2XL  | 40,000 | 500,000      | 60GB              | 8,000            | m6a.48xlarge  | io2       | 16,000 |

## Releases

### Amazon EC2 AMIs

See [CHANGLOG.md](CHANGELOG.md) for the completed list.