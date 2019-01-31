# Pharos Cluster Vagrant

Pharos Cluster Vagrant setup mainly for local testing.

## Quickstart

```sh
$ vagrant up
$ pharos up
$ export KUBECONFIG=~/.pharos/192.168.100.100
$ kubectl get nodes
```

## Teardown

Complete teardown:
```sh
$ vagrant destroy
```

"Soft" teardown, stops and removes all kube related configs/pods etc.:
```sh
ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.100.100 sudo kubeadm reset
ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.100.101 sudo kubeadm reset
ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.100.102 sudo kubeadm reset
```

### Testing etcd with certs

`etcd_certs` dir has suitable certs for local testing, assuming etcd running on the same host as kube master components.

Setup etcd on host-00:
```sh
$ vagrant up
$ ssh -i ~/.vagrant.d/insecure_private_key vagrant@192.168.100.100

vagrant@host-00:~$ sudo docker run -d -v /vagrant/etcd_certs:/certs  -p 2379:2379   -p 2380:2380   -v /tmp/etcd-data.tmp:/etcd-data   --name etcd   gcr.io/etcd-development/etcd:v3.3.2   /usr/local/bin/etcd   --name s1   --data-dir /etcd-data   --listen-client-urls https://0.0.0.0:2379   --advertise-client-urls https://127.0.0.1:2379   --listen-peer-urls http://0.0.0.0:2380   --initial-advertise-peer-urls http://0.0.0.0:2380   --initial-cluster s1=http://0.0.0.0:2380   --initial-cluster-token tkn --cert-file=/certs/server.pem --key-file=/certs/server-key.pem --client-cert-auth --trusted-ca-file=/certs/ca.pem
```

```
$ kupo up -c cluster-external-etcd.yml
$ export KUBECONFIG=~/.kupo/192.168.100.100
$ kubectl get nodes
```


## License

Copyright (c) 2018 Kontena, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
