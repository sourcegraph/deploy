#!/bin/bash
SOURCEGRAPH_VERSION='4.0.1'
HELM_RUNNING_VERSION=$(/usr/local/bin/helm history sourcegraph | grep -oE "(4\.0\..|3\.43\..) \s")
if [ "$HELM_RUNNING_VERSION" != "" ] && [ "$HELM_RUNNING_VERSION" != "$SOURCEGRAPH_VERSION" ]; then
    /usr/local/bin/helm upgrade --install --values /home/ec2-user/deploy/dev/override.yaml --version "${SOURCEGRAPH_VERSION}" sourcegraph sourcegraph/sourcegraph
fi
