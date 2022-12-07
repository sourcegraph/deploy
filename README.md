# sourcegraph/deploy: one-click Sourcegraph deployments

**This repository is for Sourcegraph developers: for how to deploy Sourcegraph, please see [docs.sourcegraph.com](https://docs.sourcegraph.com)**

This repository is home of Sourcegraph one-click deployments (AMIs, VM images, etc.) distributed through various cloud providers.

## Overview

- [Development](./doc/development.md)
- [Debugging](./doc/debugging.md)
- [Manual AMI creation](./doc/manual-ami.md)
- [Official Docs](https://docs.sourcegraph.com/admin/deploy/machine-images)

## Instance size chart

We use T-shirt sizes which are based on the results from our [load tests](https://github.com/sourcegraph/k6).

| Size | Users  | Repositories | Largest Repo Size | Concurrent Users |
| ---- | ------ | ------------ | ----------------- | ---------------- |
| XS   | 00,500 | 1,000        | 5GB               | 100              |
| S    | 01,000 | 10,000       | 23GB              | 200              |
| M    | 05,000 | 50,000       | 23GB              | 1,000            |
| L    | 10,000 | 100,000      | 35GB              | 2,000            |
| XL   | 20,000 | 250,000      | 35GB              | 4,000            |

## Sourcegraph Machine Images

All instances launched from the offical Sourcegraph machine images are deployed into a single K3s server cluster, running on a single node with an embedded SQLite Database. It allows us to package all the Sourcegraph services with necessary components into one single launcher image so that you can spin up a Sourcegraph instance with just a few clicks in less than 10 minutes.

All Sourcegraph machine image instances come with:

- A pre-configured Sourcegraph instance for your deployment
- A root EBS volume with 50GB of storage
- An additional EBS volume with 500GB of storage for storing code and search indices

Please see our [official docs on machine image](https://docs.sourcegraph.com/admin/deploy/machine-images) for more information about our machine images, including detailed instructions for deploying with our images.

## Sourcegraph AMI instance

A Sourcegraph instance created with the Sourcegraph AWS AMIs that are built using our packer image-building pipeline with the install.sh script.

> NOTE: The default username is `**ec2-user**`

### AWS Regions

Please reach out to us if you are not able to find Sourcegraph images for your region.

## Sourcegraph Azure image instance

[COMING SOON] A Sourcegraph instance created by using the Sourcegraph Azure image.

## Sourcegraph Google machine image instance

A Sourcegraph instance created by using the Sourcegraph Google machine images.

> NOTE: The default username is `sourcegraph`

## Releases

See our [Changelog](./CHANGELOG.md) and [Releases](https://github.com/sourcegraph/deploy/releases) page for more information on all of our releases.
