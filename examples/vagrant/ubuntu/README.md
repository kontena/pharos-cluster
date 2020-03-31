# Pharos Cluster Vagrant

Pharos Cluster Vagrant setup mainly for local testing.

## Quickstart

```sh
$ vagrant up
$ pharos-cluster up
$ mkdir ~/.kube && chmod 0700 ~/.kube
$ pharos kubeconfig > ~/.kube/config
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
$ pharos up -c cluster-external-etcd.yml
$ pharos kubeconfig -c cluster-external-etcd.yml > ~/.kube/config
$ kubectl get nodes
```
