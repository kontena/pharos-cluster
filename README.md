# Shokunin

Kubernetes cluster artisan, a simple, fast Kubernetes installer that works everywhere.

## Requirements

- Minimal Ubuntu 16.04 nodes with SSH access
- Swap disabled on all nodes

## Usage

```
$ shokunin build -c cluster.yml
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
features:
  host_updates:
    interval: "7d"
    reboot: true
  network:
    settings:
      trusted_subnets:
        - "172.31.0.0/16"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kontena/shokunin.

## Licence

Copyright (c) 2018 Kontena, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

