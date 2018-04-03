# Pharos Cluster

[![Build Status](https://cloud-drone-07.kontena.io/api/badges/kontena/kupo/status.svg)](https://cloud-drone-07.kontena.io/kontena/kupo)

Kontena Pharos cluster installer.

## Requirements

- Minimal Ubuntu 16.04 nodes with SSH access

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

## Network Options

- `service_cidr` - IP address range for service VIPs. (default "10.96.0.0/12")
- `pod_network_cidr` - IP address range for the pod network. (default "10.32.0.0/12")
- `trusted_subnets` - array of trusted subnets where overlay network can be used without IPSEC.

## Using external etcd

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

## Webhook Token Authentication

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

## Audit Webhook

Cluster supports setting up audit webhooks for external audit event collection.

```yaml
audit:
 server: "http://audit.example.com/webhook"
```

Audit events are delivered in batched mode, multiple events in one webhook `POST` request.

Currently audit events are configured to be emitted at `Metadata` level. See: https://github.com/kubernetes/community/blob/master/contributors/design-proposals/api-machinery/auditing.md#levels

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

### Host Upgrades

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/pharos-cluster.

## License

Copyright (c) 2018 Kontena, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

