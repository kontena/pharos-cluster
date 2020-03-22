# Pharos Cluster on Packet.net (using Terraform)


## Prerequisities

- Pharos [toolchain](https://docs.k8spharos.dev/install.html) installed locally
- [Terraform](https://www.terraform.io/) 0.12 installed locally
- [Packet.com](https://packet.com) credentials

## Clone this repository

```
$ git clone https://github.com/kontena/pharos-cluster.git
$ cd pharos-cluster/examples/terraform-packet/
```

## Configure Terraform

Copy [terraform.example.tfvars](./terraform.example.tfvars) example file to `terraform.tfvars`:

```
$ cp terraform.example.tfvars terraform.tfvars
```

Edit `project_id` and `auth_token`. Optionally you can also configure number of machines and their types. Once done save the file.

## Create Cluster

```
$ pharos tf apply -y --trust-hosts
```

This command will first execute Terraform to create the infrastructure, collects host information and passes this information back to `pharos`.

## Teardown Cluster

```
$ pharos tf destroy
```
