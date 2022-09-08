# sourcegraph/deploy developers guide

# Creating a prototype instance

1. Create an Amazon Linux 2 EC2 instance (e.g. `m5a.4xlarge`)
2. Add a 50G root EBS volume (gp3), and a 500G data EBS volume (gp3)
3. SSH into the box, run:

```sh
sudo yum update -y
sudo yum install -y git
git clone https://github.com/sourcegraph/deploy
cd deploy/dev
./install.sh
```

4. Run `kubectl get pods` and `kubectl get svc` to see the pods/services. Wait a few minutes for them all to be running.
5. Navigate to the public IP of the EC2 instance in a browser (you may need to create an elastic IP and associate it with your EC2 instance)

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
