# Authentication Token Webhook

Example authentication token webhook configuration

## Quickstart

1. Edit cluster.yml
```
...
authentication:
  token_webhook:
    config:
      cluster:
        name: token-reviewer
        server: http://localhost:9292/token
      user:
        name: k8s-apiserver
...
```

2. Kupo up

```sh
$ kupo up
$ export KUBECONFIG=~/.kupo/<master-ip>
```

3. Deploy token reviewer service

```sh
$ kubectl apply -f ./examples/authentication-token-webhook/deploy
```
The default user and token are `admin/verysecret`, but you can edit `daemonset.yml` and `cluster_role_binding.yml` to change those.

4. Request API server with the token
```sh
$ curl -X GET \
  https://<master-ip>:6443/api/v1/nodes \
  -H 'authorization: Bearer verysecret' \
  -H 'cache-control: no-cache'
```

