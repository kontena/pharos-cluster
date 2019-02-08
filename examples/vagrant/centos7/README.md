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


## Teardown

Complete teardown:
```sh
$ vagrant destroy
```
This will destroy the VMs and all state related to them.