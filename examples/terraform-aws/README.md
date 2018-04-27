# HA Pharos Cluster on AWS (using Terraform)

```
$ terraform init
$ terraform plan
$ terraform apply
$ terraform output -json > tf.json
$ pharos-cluster up --hosts-from-tf=./tf.json
```