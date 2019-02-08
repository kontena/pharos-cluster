# Results of kube-bench runs

Tests run at 31.1.2019 by @jnummelin.

## Master

### 1.1.1

```
[FAIL] 1.1.1 Ensure that the --anonymous-auth argument is set to false (Scored)
```

Cannot be set to false currently with kubeadm as it totally breaks the api-server probes. See https://github.com/kubernetes/kubeadm/issues/798


### 1.1.13

```
[FAIL] 1.1.13 Ensure that the admission control plugin SecurityContextDeny is set (Scored)
```

Cannot be set as some of the system pods (i.e. Weave) needs to set `pod.Spec.SecurityContext.SELinuxOptions`


### 1.1.36

```
[FAIL] 1.1.36 Ensure that the admission control plugin EventRateLimit is set (Scored)
```

`EventRateLimit` controller is still alpha. Also mitigated by having rate limiting on kubelet side.

### 1.3.6

```
[FAIL] 1.3.6 Ensure that the RotateKubeletServerCertificate argument is set to true (Scored)
```

This is actually false positive, this config is set on the kubelet config file in `/var/lib/kubelet/config.yaml`

### 1.4.7 & 1.4.8

```
[FAIL] 1.4.7 Ensure that the etcd pod specification file permissions are set to 644 or more restrictive (Scored)
[FAIL] 1.4.8 Ensure that the etcd pod specification file ownership is set to root:root (Scored)
```

These are false positives, kube-bench by default looks for different files: https://github.com/aquasecurity/kube-bench/blob/master/cfg/1.11/config.yaml#L21

```sh
# stat -c %a /etc/kubernetes/manifests/pharos-etcd.yaml
644
```

### 1.4.2

```
[FAIL] 1.4.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Scored)
```

Pharos uses etcd data dir from a host mount. Having separate ownership for it does not matter that much as it's anyway mounted in the etcd container.




## Worker

## `--allow-privileged`

```
[FAIL] 2.1.1 Ensure that the --allow-privileged argument is set to false (Scored)
```

We cannot set that as both the network providers we support need to run with privileged flag on.

## `--anonymous-auth`

```
[FAIL] 2.1.2 Ensure that the --anonymous-auth argument is set to false (Scored)
```

False positive, we have this set:
```
authentication:
  anonymous:
    enabled: false
```

## --authorization-mode

```
[FAIL] 2.1.3 Ensure that the --authorization-mode argument is not set to AlwaysAllow (Scored)
```

False positive, set in config file:
```yaml
authorization:
  mode: Webhook
```


## client-ca-file

```
[FAIL] 2.1.4 Ensure that the --client-ca-file argument is set as appropriate (Scored)
```

False positive, everything set in config file:
```
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
```

## --read-only-port

```
[FAIL] 2.1.5 Ensure that the --read-only-port argument is set to 0 (Scored)
```

--> No action, 1.13 does not have the flag anymore at all.

## streaming-connection-idle-timeout

```
[FAIL] 2.1.6 Ensure that the --streaming-connection-idle-timeout argument is not set to 0 (Scored)
```

False positive, set to 4h in the config file

## protect-kernel-defaults

```
[FAIL] 2.1.7 Ensure that the --protect-kernel-defaults argument is set to true (Scored)
```

Cannot be set safely, causes kubelet startup failures. This flag is pretty nonsense anyway, one cannot run with any other kernel params that kubelet wants anyway. See:
- https://github.com/kubernetes/kubernetes/issues/66693


## hostname-override

```
[FAIL] 2.1.9 Ensure that the --hostname-override argument is not set (Scored)
```

Not setting this causes some issues in cluster setup. The risk is also really low that this would cause any issues.

> Overriding hostnames could potentially break TLS setup between the kubelet and the apiserver. Additionally, with overridden hostnames, it becomes increasingly difficult to associate logs with a particular node and process them for security analytics. Hence, you should setup your kubelet nodes with resolvable FQDNs and avoid overriding the hostnames with IPs.

## --event-qps

```
[FAIL] 2.1.10 Ensure that the --event-qps argument is set to 0 (Scored)
```

False positive, set in config file:
```
eventBurst: 10
eventRecordQPS: 5
```


## --tls-cert-file and --tls-private-key-file

```
[FAIL] 2.1.11 Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Scored)
```

False positive, these are configured via automatic TLS bootsrapping.


## --rotate-certificates

```
[FAIL] 2.1.13 Ensure that the --rotate-certificates argument is not set to false (Scored)
```

False positive, set in config file:
```
rotateCertificates: true
```

## RotateKubeletServerCertificate

```
[FAIL] 2.1.14 Ensure that the RotateKubeletServerCertificate argument is set to true (Scored)
```

False positive, defaults to true 1.12 onwards

## Strong Cryptographic Ciphers

```
[FAIL] 2.1.15 Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Not Scored)
```

False positive, configured in kubelet config file:
```yaml
tlsCipherSuites:
- TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
- TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
- TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
- TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_256_GCM_SHA384
- TLS_RSA_WITH_AES_128_GCM_SHA256
```

## File permissions

```
[FAIL] 2.2.3 Ensure that the kubelet service file permissions are set to 644 or more restrictive (Scored)
[FAIL] 2.2.5 Ensure that the proxy kubeconfig file permissions are set to 644 or more restrictive (Scored)
[FAIL] 2.2.6 Ensure that the proxy kubeconfig file ownership is set to root:root (Scored)
[WARN] 2.2.7 Ensure that the certificate authorities file permissions are set to 644 or more restrictive (Scored)
[WARN] 2.2.8 Ensure that the client certificate authorities file ownership is set to root:root (Scored)
```

These are not created/managed by Pharos directly.


