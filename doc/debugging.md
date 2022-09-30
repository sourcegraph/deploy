# Debugging Sourcegraph AMI deployments

## Checking the state of the system

```sh
kubectl get pods -A
```

## Networking

If facing networking challenges, it can be helpful to run ping etc. from inside a container in the cluster rather than on the host machine:

```sh
kubectl run -it --rm busybox --image=busybox sh
```

## Checking storage provisioner logs

If there are disk / persistent volume issues, you can check the storage provisioner like so:

```sh
kubectl -n local-path-storage logs -f -l app=local-path-provisioner
```

## Stopping/starting/restarting k3s

```sh
systemctl stop k3s
systemctl start k3s
systemctl restart k3s
```

## Killing k3s

By default, k3s allows high availability during upgrades, so the K3s containers continue running when the K3s service is stopped/restarted via `systemctl`.

To stop all of the K3s containers and reset the containerd state, the `k3s-killall.sh` script (on the PATH already) can be used:

```sh
k3s-killall.sh
```

Once ran, `systemctl start k3s` can bring back k3s (no Sourcegraph data would be lost)

## Error: cluster outage:

If you encounter an error about cluster outages:

`FATA[0000] /var/lib/rancher/k3s/server/tls/client-ca.key, /var/lib/rancher/k3s/server/tls/etcd/peer-ca.crt, /var/lib/rancher/k3s/server/tls/etcd/peer-ca.key, /var/lib/rancher/k3s/server/tls/etcd/server-ca.crt, /var/lib/rancher/k3s/server/tls/etcd/server-ca.key, /var/lib/rancher/k3s/server/tls/request-header-ca.crt, /var/lib/rancher/k3s/server/tls/server-ca.key, /var/lib/rancher/k3s/server/tls/client-ca.crt, /var/lib/rancher/k3s/server/tls/request-header-ca.key, /var/lib/rancher/k3s/server/tls/server-ca.crt, /var/lib/rancher/k3s/server/tls/service.key, /var/lib/rancher/k3s/server/cred/ipsec.psk newer than datastore and could cause a cluster outage. Remove the file(s) from disk and restart to be recreated from datastore.`

To fix this, remove the tls certs and creds that were used in the old instance with:

```bash
rm -rf /var/lib/rancher/k3s/server/cred/ /var/lib/rancher/k3s/server/tls/
```

## Error: `serviceipallocations`

`Unable to perform initial Kubernetes service initialization: Service "kubernetes" is invalid: spec.clusterIPs: Invalid value: []string{"10.43.0.1"}: failed to allocate IP 10.43.0.1: cannot allocate resources of type serviceipallocations at this time`

A: Remove all the cluster related data with the command below. Data inside the volumes will not be removed.

```bash
sh /usr/local/bin/k3s-killall.sh
```

## Problem: Failed to set up base instance during building an AMI using the user-data.sh script

A: Check the logs for clues:

```bash
tail -f /var/log/cloud-init-output.log
```
