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

Copy [terraform.example.tfvars](./terraform.example.tfvars) example file to `terraform.tfvars`:

```
$ cp terraform.example.tfvars terraform.tfvars
```

Edit `project_id` and `auth_token`. Optionally you can also configure number of machines and their types. Once done save the file.

## Create Cluster

```
$ pharos tf apply
```

## Teardown Cluster

```
$ pharos tf destroy
```
