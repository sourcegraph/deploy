#!/usr/bin/env bash

# Wait until databases ready
until $LOCAL_BIN_PATH/kubectl get pods | grep pgsql | grep Running; do sleep 5; done
until $LOCAL_BIN_PATH/kubectl get pods | grep codeinsights-db | grep Running; do sleep 5; done
until $LOCAL_BIN_PATH/kubectl get pods | grep codeintel-db | grep Running; do sleep 5; done
echo 1 >> ~/.status
V1=$1 # old
V2=$2 # new

MV1=${V1%%.*} # remove left-most . and everything to the right of it
MV2=${V2%%.*}

mV1=${V1#"$MV1".} # remove major version suffix
mV2=${V2#"$MV2".}
mV1=${mV1%%.*} # remove left-most . and everything to the right of it
mV2=${mV2%%.*}

if [ "$MV2" -gt "$MV1" ] || (( mV2 - mV1 > 1 )); then # MVU
    # Restart k3s if it is erroring
    echo 2 >> ~/.status
    until $LOCAL_BIN_PATH/kubectl get pods -A | grep helm-install-traefik-crd | grep Completed; do
        sudo systemctl restart k3s
        sleep 30
    done
    echo 3 >> ~/.status
    # Stop running services
    $LOCAL_BIN_PATH/kubectl scale deployment --all --replicas=0
    $LOCAL_BIN_PATH/kubectl scale sts gitserver indexed-search --replicas=0

    echo Upgrading from "$MV1"."$mV1" to "$MV2"."$mV2"
    $LOCAL_BIN_PATH/helm install --kubeconfig $KUBECONFIG_FILE --set-json='migrator.args=["upgrade", "--from", "'"$MV1.$mV1"'", "--to", "'"$MV2.$mV2"'"]' sourcegraph-migrator ./sourcegraph-migrator-charts.tgz
    until $LOCAL_BIN_PATH/kubectl get pods | grep migrator | grep Completed; do sleep 5; done
    $LOCAL_BIN_PATH/helm --kubeconfig $KUBECONFIG_FILE uninstall sourcegraph-migrator
    echo 4 >> ~/.status
elif [ "$MV2" -eq "$MV1" ] && [ "$mV2" -eq "$mV1" ] ; then # Same version
    : # Pass
elif [ "$MV1" -gt "$MV2" ] || (( mV1 - mV2 > 1 )); then # Downgrade
    : # 
fi
echo 5 >> ~/.status