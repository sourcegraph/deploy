# sourcegraph/deploy developers guide

# Creating a prototype instance

1. Create an Amazon Linux 2 EC2 instance (e.g. `m5a.4xlarge`)
2. SSH into the box
3. Create an `override.yaml` file (use the one in this directory)
4. Create an `ingress.yaml` file (use the one in this directory)
5. Run `install.sh`
6. Run `kubectl get pods` and `kubectl get svc` to see the pods/services. Wait a few minutes for them all to be running.
7. Navigate to the public IP of the EC2 instance in a browser (you may need to create an elastic IP and pointer it at your EC2 instance)

## Known issues

### k3s config file issues

I had to add `--write-kubeconfig-mode 644` to the k3s install script in order to get a working cluster, but then after doing so we get these warnings:

```
WARNING: Kubernetes configuration file is group-readable. This is insecure. Location: /etc/rancher/k3s/k3s.yaml
WARNING: Kubernetes configuration file is world-readable. This is insecure. Location: /etc/rancher/k3s/k3s.yaml
```

### env var to fix kubectl

The install script exports this, but we need it to be persistent otherwise `kubectl` won't work when you SSH into the box:

```
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

## Debugging tips

### Networking

If facing networking challenges, it can be helpful to run ping etc. from inside a container in the cluster rather than on the host machine:

```sh
kubectl run -it --rm --restart=never busybox --image=busybox sh
```

### Checking storage provisioner logs

If there are disk / persistent volume issues, you can check the storage provisioner like so:

```sh
kubectl -n local-path-storage logs -f -l app=local-path-provisioner
```
