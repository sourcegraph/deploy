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
| XS   | 00,500 | 1,000        | 5GB               | 100              | m6a.2xlarge   | 500GB gp3 |        |
| S    | 01,000 | 10,000       | 23GB              | 200              | m6a.4xlarge   | 1TB gp3   |        |
| M    | 05,000 | 50,000       | 23GB              | 1,000            | m6a.8xlarge   | 2TB gp3   |        |
| L    | 10,000 | 100,000      | 35GB              | 2,000            | m6a.12xlarge  | 5TB io2   | 16,000 |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            | m6a.24xlarge  | io2       | 16,000 |
| 2XL  | 40,000 | 500,000      | 60GB              | 8,000            | m6a.48xlarge  | io2       | 16,000 |

## Releases

### v4.0.0

#### Amazon EC2 AMIs

| Size | AMI ID                | Source                                                     |
|------|-----------------------|------------------------------------------------------------|
| XS   | ami-0ee5cdc5e89a4bee2 | 185007729374/sourcegraph-XS (v4.0.0) m6a.2xlarge           |
| S    | ami-09b82ce5a7b1759a8 | 185007729374/sourcegraph-s-4-0-0-m6a-4xlarge-2022-09-29    |
| M    | ami-09fe07a328a24f288 | 185007729374/sourcegraph-m-4-0-0-m6a-8xlarge-2022-09-29    |
| L    | ami-021db30b6db9b0634 | 185007729374/sourcegraph-L (v4.0.0) m6a.12xlarge           |
| XL   | ami-04b10e0fabedb6eac | 185007729374/sourcegraph-XL (v4.0.0) m6a.24xlarge          |
