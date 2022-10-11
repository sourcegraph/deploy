# Debugging Sourcegraph AMI deployments

Run all the commands listed below from the root of this repository.

## Missing cluster metrics in Grafana

This is a known issue for AMI instances on v4.0.0 and v4.0.1 as an updated configMap is required:

```bash
# Step 1: Install the configMap override file for prometheus
kubectl apply -f ./install/prometheus-override.ConfigMap.yaml
# Step 2: Delete the existing prometheus pod so that a new one will be created with the new configMap
kubectl delete pod <prometheus pod>
```

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
# Stop
sudo systemctl stop k3s
# Start
sudo systemctl start k3s
# Restart
sudo systemctl restart k3s
```

## Killing k3s

By default, k3s allows high availability during upgrades, so the K3s containers continue running when the K3s service is stopped/restarted via `systemctl`.

To stop all of the K3s containers and reset the containerd state, the `k3s-killall.sh` script (on the PATH already) can be used:

```sh
bash k3s-killall.sh
```

Once ran, `sudo k get systemctl start k3s` can bring back k3s (no Sourcegraph data would be lost)

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
sudo tail -f /var/log/cloud-init-output.log
```

## Deploy using local helm charts

```bash
# Update 4.0.0 with your version number when needed
helm upgrade -i -f /home/ec2-user/deploy/install/override.yaml --version 4.0.0 sourcegraph /home/ec2-user/deploy/install/sourcegraph-charts.tgz --kubeconfig /etc/rancher/k3s/k3s.yaml
# v.s. using remote helm charts
helm upgrade -i -f /home/ec2-user/deploy/install/override.yaml --version 4.0.0 sourcegraph sourcegraph/sourcegraph --kubeconfig /etc/rancher/k3s/k3s.yaml
```

## Check prometheus metrics

```bash
# 1: Port forward the Prometheus deployment to port 9090 
kubectl port-forward deploy/prometheus 9090:9090
# 2: Connect the AWS VM port 9090 to your localhost port 9090
ssh -i ~/.ssh/<ssh-key> -L 9090:localhost:9090 ec2-user@<instance-ip>
```
You now have access to Prometheus on http://localhost:9090 in your browser

## Check metrics scrapped by cadvisor

```bash
# sourcegraph-0 is the name of the node
kubectl get --raw /api/v1/nodes/sourcegraph-0/proxy/metrics/cadvisor --kubeconfig /etc/rancher/k3s/k3s.yaml
```

## Upgrade

```bash
helm --kubeconfig /etc/rancher/k3s/k3s.yaml upgrade -i -f /home/sourcegraph/deploy/install/override.yaml sourcegraph sourcegraph/sourcegraph
```