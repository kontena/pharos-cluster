# Pharos Cluster on Packet.net (using Terraform)


## Prerequisities

- Kontena Pharos [toolchain](https://www.pharos.sh/docs/install.html) installed locally
- [Terraform](https://www.terraform.io/) installed locally
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
$ pharos tf apply
```

## Teardown Cluster

```
$ pharos tf destroy
```
