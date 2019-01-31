# Pharos Cluster on Packet.net (using Terraform)


## Prerequisities

- Kontena Pharos [toolchain](https://www.pharos.sh/docs/install.html) installed locally
- Packet.net credentials


## Install the latest version

```
$ chpharos install --use latest
```

## Configure Terraform

```
$ cp terraform.example.tfvars terraform.tfvars
```

Fill `project_id` & `auth_token` to `terraform.tfvars`.

## Create Cluster

```
$ terraform init
$ terraform apply
$ terraform output -json > tf.json
$ pharos up --tf-json tf.json
```

## Teardown Cluster

```
$ terraform destroy && rm tf.json
```
