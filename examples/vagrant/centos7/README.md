# Pharos Cluster with Vagrant & CentOS hosts

Pharos Cluster Vagrant setup for local testing using Vagrant and CentOS hosts.

## Prerequisities

- Kontena Pharos [toolchain](https://www.pharos.sh/docs/install.html) installed locally
- Vagrant [toolchain installed](https://www.vagrantup.com/docs/installation/)
- Copy of `Vagrantfile` and `cluster.yml` in this directory available locally

## Install the latest version of Pharos CLI tool

```
$ chpharos install --use latest
```

## Quickstart

```sh
$ vagrant up
$ pharos up
$ pharos kubeconfig > kubeconfig
$ export KUBECONFIG=kubeconfig
$ kubectl get nodes
```

Now you cluster is ready to take in your workloads.

## Walkthrough

Let's take a look what each of the steps actually does.


```sh
$ vagrant up
```

This will ensure that the virtual machines managed by [Vagrant](https://www.vagrantup.com) are up-and-running.

```sh
$ pharos up
```

This invokes Pharos CLI tool to setup and [configure](https://www.pharos.sh/docs/configuration.html) the Kubernetes cluster according to given `cluster.yml` file.

```sh
$ pharos kubeconfig > kubeconfig
```

This downloads the [configuration file](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) used for accessing the cluster for administrative purposes. This is somewhat analogous to having `root` access, so keep it safe.

```sh
$ export KUBECONFIG=kubeconfig
```

Sets up the downloaded access configuration to be used by [kubectl](https://kubernetes.io/docs/concepts/overview/object-management-kubectl/) and other such tools.

```sh
$ kubectl get nodes
```

Lists the nodes taking part in the cluster.


## Network LB

In this example we'll also deploy the [Kontena Network Loadbalancer](https://www.pharos.sh/docs/addons/kontena-network-lb.html) addon. It allows easy experimentation with `LoadBalancer` type services on Kubernetes.

In this example the nodes are allocated with `192.168.110.100-192.168.110.103` addresses. Kontena Network LB will be configured with address pool `192.168.110.110-192.168.110.150`.

To test out, let's create first a `Deployment` for Nginx:
```sh
$ kubectl run nginx --image=nginx
```

Then we need to expose that with a `LoadBalancer` type `Service`:
```sh
$ kubectl expose deployment nginx --port=80 --type=LoadBalancer
```

That will make the Network LB to select a free address from the configured pool and make the service available on that address:
```sh
$ kubectl get svc
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)        AGE
kubernetes   ClusterIP      172.32.0.1      <none>            443/TCP        4m46s
nginx        LoadBalancer   172.32.34.151   192.168.110.110   80:30464/TCP   11s
```

We cna use the service address directly to access our Nginx deployment:
```sh
$ curl 192.168.110.110
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## Teardown

Complete teardown:
```sh
$ vagrant destroy
```
This will destroy the VMs and all state related to them.