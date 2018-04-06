# Pharos Cluster

[![Build Status](https://cloud-drone-07.kontena.io/api/badges/kontena/pharos-cluster/status.svg)](https://cloud-drone-07.kontena.io/kontena/pharos-cluster)
[![Join the chat at https://slack.kontena.io](https://slack.kontena.io/badge.svg)](https://slack.kontena.io)

Kontena Pharos cluster manager.

- [Introduction](#introduction)
- [Design Principles](#design-principles)
- [Installation](#installation)
- [Host Requirements](#host-requirements)
- [Usage](#usage)
  - [Network Options](#network-options)
  - [External etcd](#using-external-etcd)
  - [Webhook Token Authentication](#webhook-token-authentication)
  - [Audit Webhook](#audit-webhook)
  - [Cloud Provider](#cloud-provider)
  - [Terraform](#usage-with-terraform)
- [Addons](#addons)
  - [Ingress NGINX](#ingress-nginx)
  - [Cert Manager](#cert-manager)
  - [Host Security Updates](#host-security-updates)
  - [Kured](#kured)
  - [Kubernetes Dashboard](#kubernetes-dashboard)

## Introduction

Pharos Cluster is a [Kontena Pharos](https://pharos.sh) (Kubernetes distribution) management tool. It handles cluster bootstrapping, upgrades and other maintenance tasks via SSH connection and Kubernetes API access.

## Design Principles

- Simple setup process and learning curve
- Bare metal friendly, infrastructure agnostic
- Manage remote clusters instantly, without bootstrapping

## Installation

Pharos Cluster executable can be downloaded from [https://github.com/kontena/pharos-cluster/releases](releases). Binaries should work on any recent 64bit MacOS or Linux machine.

## Host Requirements

- Minimal Ubuntu 16.04 (amd64 / arm64) hosts with SSH access
- A user with passwordless sudo permission (`echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER`)

### Required Open Ports

The following ports are used by the `pharos-cluster` management tool, as well as between nodes in the same cluster. These ports are all authenticated, and can safely be left open for public access if desired.

| Protocol    | Port        | Service         | Hosts / Addon         | Notes
|-------------|-------------|-----------------|-----------------------|-------
| TCP         | 22          | SSH             | All                   | authenticated management channel for `pharos-cluster` operations using SSH keys
| TCP         | 6443        | kube-apiserver  | Master                | authenticated kube API for `pharos-cluster`, `kubectl` and worker node `kubelet` access using kube API tokens, RBAC
| TCP         | 6783        | weave control   | All (weave)           | authenticated Weave peer control connections using the shared weave secret
| UDP         | 6783        | weave dataplane | All (weave)           | authenticated Weave `sleeve` fallback using the shared weave secret
| UDP         | 6784        | weave dataplane | All (weave)           | unauthenticated Weave `fastdp` (VXLAN), only used for peers on `network.trusted_subnets` networks
| ESP (IPSec) |             | weave dataplane | All (weave)           | authenticated Weave `fastdp` (IPsec encapsulated UDP port 6784 VXLAN) using IPSec SAs established over the control channel
| TCP         | 10250       | kubelet         | All                   | authenticated kubelet API for the master node `kube-apiserver` (and `heapster`/`metrics-server` addons) using TLS client certs

If using the `ingress-nginx` addon, then TCP ports 80/443 on the worker nodes (or nodes matching `addons.ingress-nginx.node_selector`) must also be opened for public access.

### Monitoring Ports

The following ports serve unauthenticated monitoring/debugging information, and are either disabled, limited to localhost-only or only expose relatively harmless information.

| Protocol    | Port        | Service               | Hosts   | Status          | Notes
|-------------|-------------|-----------------------|---------|-----------------|-------
| TCP         | 6781        | weave-npc metrics     | All     | **OPEN**        | unauthenticated `/metrics`
| TCP         | 6782        | weave status          | All     | localhost-only  | unauthenticated read-only weave `/status`, `/metrics` and `/report`
| TCP         | 10255       | kubelet read-only     | All     | *disabled*      | unauthenticated read-only `/pods`, various stats metrics
| TCP         | 10248       | kubelet               | All     | localhost-only  | ?
| TCP         | 10249       | kube-proxy metrics    | All     | localhost-only  | ?
| TCP         | 10251       | kube-scheduler        | Master  | localhost-only  | ?
| TCP         | 10252       | kube-controller       | Master  | localhost-only  | ?
| TCP         | 10256       | kube-proxy healthz    | All     | **OPEN**        | unauthenticated `/healthz`
| TCP         | 18080       | ingress-nginx status  | Workers | **OPEN**        | unauthenticated `/healthz`, `/nginx_status` and default backend

These ports should be restricted from external access to prevent information leaks.

### Restricted Ports

The following restricted services are only accessible via localhost the nodes, and must not be exposed to any untrusted access.

| Protocol    | Port        | Service               | Hosts   | Status          | Notes
|-------------|-------------|-----------------------|---------|-----------------|------
| TCP         | 2379        | etcd clients          | Master  | localhost-only  | unauthenticated etcd client API
| TCP         | 2380        | etcd peers            | Master  | localhost-only  | unauthenticated etcd peers API
| TCP         | 6784        | weave control         | All     | localhost-only  | unauthenticated weave control API

## Usage

```
$ pharos-cluster up -c cluster.yml
```

Example cluster YAML:

```yaml
hosts:
  - address: "1.1.1.1"
    private_address: "1.0.1.0"
    user: root
    ssh_key_path: ~/.ssh/my_key
    role: master
  - address: "2.2.2.2"
    role: worker
    labels:
      key: value
  - address: "3.3.3.3"
    role: worker
network:
  trusted_subnets:
    - "172.31.0.0/16"
addons:
  ingress-nginx:
    enabled: true
    configmap:
      load-balance: least_conn
  host-upgrades:
    enabled: true
    interval: 7d
  kured:
    enabled: true
```

You can view full sample of cluster.yml [here](./cluster.example.yml).

### Hosts
- `address` - IP address or hostname
- `role` - One of `master`, `worker`
- `private_address` - Private IP address or hostname. Prefered for cluster's internal communication where possible (optional)
- `user` - Username with sudo permission to use for logging in (default  "ubuntu")
- `ssh_key_path` - A local file path to an ssh private key file (default "~/.ssh/id_rsa")
- `container_runtime` - One of `docker`, `cri-o` (default "docker")
- `labels` - A list of `key: value` pairs to assign to the host (optional)

### Network Options

- `service_cidr` - IP address range for service VIPs. (default "10.96.0.0/12")
- `pod_network_cidr` - IP address range for the pod network. (default "10.32.0.0/12")
- `trusted_subnets` - array of trusted subnets where overlay network can be used without IPSEC.

### Using External etcd

Pharos Cluster can spin up Kubernetes using an externally managed etcd. In this case you need to define the external etcd details in your `cluster.yml` file:

```yaml
etcd:
  endpoints:
    - https://etcd-1.example.com:2379
    - https://etcd-2.example.com:2379
    - https://etcd-3.example.com:2379
  certificate: ./etcd_certs/client.pem
  key: ./etcd_certs/client-key.pem
  ca_certificate: ./etcd_certs/ca.pem
```

You need to specify all etcd peer endpoints in the list.

Certificate and corresponding key is used to authenticate the access to etcd. The paths used are relative to the path where the `cluster.yml` file was loaded from.

### Webhook Token Authentication

Cluster supports [webhook for verifying bearer tokens](https://kubernetes.io/docs/admin/authentication/#webhook-token-authentication).

```yaml
authentication:
  token_webhook:
    config:
      cluster:
        name: token-reviewer
        server: http://localhost:9292/token
        certificate_authority: /path/to/ca.pem # optional
      user:
        name: kube-apiserver
        client_key: /path/to/key.pem # optional
        client_certificate: /path/to/cert.pem # optional
    cache_ttl: 5m # optional
```

### Audit Webhook

Cluster supports setting up audit webhooks for external audit event collection.

```yaml
audit:
 server: "http://audit.example.com/webhook"
```

Audit events are delivered in batched mode, multiple events in one webhook `POST` request.

Currently audit events are configured to be emitted at `Metadata` level. See: https://github.com/kubernetes/community/blob/master/contributors/design-proposals/api-machinery/auditing.md#levels

### Cloud Provider

Pharos Cluster supports a concept of [cloud providers](https://kubernetes.io/docs/getting-started-guides/scratch/#cloud-provider). Cloud provider is a module that provides an interface for managing load balancers, nodes (i.e. hosts) and networking routes.

```yaml
cloud:
  provider: aws
```

### Options

- `provider` - specify used cloud provider (default: no cloud provider)

### Usage with Terraform

Pharos Cluster can read host information from Terraform json output. In this scenario cluster.yml does not need to have `hosts` at all.

#### Example

**Terraform output config:**

```tf
output "pharos" {
  value = {
    masters = {
      address         = "${digitalocean_droplet.pharos_master.*.ipv4_address}"
      private_address = "${digitalocean_droplet.pharos_master.*.ipv4_address_private}"
      role            = "master"
      user            = "root"
    }

    workers_2g = {
      address         = "${digitalocean_droplet.pharos_2g.*.ipv4_address}"
      private_address = "${digitalocean_droplet.pharos_2g.*.ipv4_address_private}"
      role            = "worker"
      user            = "root"

      label = {
        droplet = "2g"
      }
    }

    workers_4g = {
      address         = "${digitalocean_droplet.pharos_4g.*.ipv4_address}"
      private_address = "${digitalocean_droplet.pharos_4g.*.ipv4_address_private}"
      role            = "worker"
      user            = "root"

      label = {
        droplet = "4g"
      }
    }
  }
}
```

**Cluster.yml:**

```yaml
network: {}
addons:
  ingress-nginx:
    enabled: true
```

**Commands:**

```sh
$ terraform apply
$ terraform output -json > tf.json
$ pharos-cluster up -c cluster.yml --hosts-from-tf ./tf.json
```

## Addons

Pharos Cluster includes common functionality as addons. Addons can be enabled by introducing and enabling them in `cluster.yml`.

### Ingress NGINX

NGINX ingress controller daemonset. By default runs on every node on ports 80 & 443.

https://github.com/kubernetes/ingress-nginx

```yaml
ingress-nginx:
  enabled: true
  node_selector:
    disk: ssd
  configmap:
    load-balance: least_conn
  default_backend:
    image: my-custom-image:latest
```
#### Options

- `node_selector` - deployment node selector (map), deploys ingress only to matching nodes.
- `configmap` - custom configuration (map). For all supported `configmap` options, see: https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/configmap.md
- `default_backend.image` - custom image to be used as the default backend for the Nginx Ingress. Expected to fulfill the default backend [requirements](https://github.com/kubernetes/ingress-nginx#requirements). Leave empty to use Pharos' own default backend.

### Cert Manager

TLS certificate automation (including Let's Encrypt).

https://github.com/jetstack/cert-manager

```yaml
cert-manager:
  enabled: true
  issuer:
    name: letsencrypt-staging
    server: https://acme-staging.api.letsencrypt.org/directory
    email: me@domain.com
```

#### Options

- `issuer.name` - registered issuer resource name
- `issuer.server`-  ACME server url
- `issuer.email` - email address used for ACME registration

### Host Security Updates

Automatic host operating system security updates.

```yaml
host-upgrades:
  enabled: true
  interval: "7d"
```

#### Options

* `interval` - how often upgrades are applied (string)

### Kured

Performs safe automatic node reboots when the need to do so is indicated by the package management system of the underlying OS.

https://github.com/weaveworks/kured

```yaml
kured:
  enabled: true
```

### Kubernetes Dashboard

Kubernetes Dashboard is a general purpose, web-based UI for Kubernetes clusters. It allows users to manage applications running in the cluster and troubleshoot them, as well as manage the cluster itself.

https://github.com/kubernetes/dashboard

```yaml
kubernetes-dashboard:
  enabled: true
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/pharos-cluster.

## License

Copyright (c) 2018 Kontena, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
