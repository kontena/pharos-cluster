# Kupo (クポ)

[![Build Status](https://cloud-drone-07.kontena.io/api/badges/kontena/kupo/status.svg)](https://cloud-drone-07.kontena.io/kontena/kupo)

Kontena Kubernetes distribution installer, kupo!

## Requirements

- Minimal Ubuntu 16.04 nodes with SSH access

## Usage

```
$ kupo build -c cluster.yml
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

## Addons

Kupo includes common functionality as addons. Addons can be enabled by introducing and enabling them in `cluster.yml`.

### Ingress NGINX

NGINX ingress controller daemonset. By default runs on every node on ports 80 & 443.

https://github.com/kubernetes/ingress-nginx

```yaml
ingress-nginx:
  enabled: true
  configmap:
    load-balance: least_conn
```
#### Options

- `node_selector`: if given, deploys ingress to only matching nodes.
- `configmap`: custom configuration (hash). For all supported `configmap` options, see: https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/configmap.md

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

- `issuer.name`: registered issuer resource name
- `issuer.server`: ACME server url
- `issuer.email`: email address used for ACME registration

### Host Upgrades

Automatic host operating system security updates.

```yaml
host-upgrades:
  enabled: true
  interval: "7d"
```

#### Options

* `interval`: how often upgrades are applied (string)

### Kured

Performs safe automatic node reboots when the need to do so is indicated by the package management system of the underlying OS.

https://github.com/weaveworks/kured

```yaml
kured:
  enabled: true
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/kupo.

## License

Copyright (c) 2018 Kontena, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

