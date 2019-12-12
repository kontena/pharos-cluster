# Pharos Cluster on Packet.net (using Terraform)


## Prerequisities

- Kontena Pharos [toolchain](https://www.pharos.sh/docs/install.html) installed locally
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

### BGP mode (optional)

It's possible to automatically configure Kontena Network LB (MetalLB) to use BGP mode if your Packet.com project has BGP enabled. Just set `bgb_address_pool` to match your BGP enabled ip address block, for example:

```
bgp_address_pool = "147.75.40.47/32"
```

## Create Cluster

```
$ pharos tf apply -y --trust-hosts
```

This command will first execute Terraform to create the infrastructure, collects host information and passes this information back to `pharos`. Finally it will configure Kontena Pharos cluster with ingress-nginx and kontena-storage addons enabled.

If `bgb_address_pool` is configured then apply will also automatically configure Kontena Network LB with BGP mode and set ingress-nginx to `Deployment` mode which will use `LoadBalancer` addresses from BGP address pool.

## Teardown Cluster

```
$ pharos tf destroy
```
