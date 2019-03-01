variable "cluster_name" {
  default = "pharos"
}

variable "region" {
  default = "ams3"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 5
}

variable "master_size" {
  default = "2gb"
}

variable "worker_size" {
  default = "2gb"
}

variable "data_volume_size" {
  default = 100
}

variable "image" {
  default = "ubuntu-18-04-x64"
}


provider "digitalocean" {
}

resource "tls_private_key" "ssh_key" {
  algorithm   = "RSA"
  rsa_bits = "4096"
}

resource "local_file" "ssh_key" {
  content     = "${tls_private_key.ssh_key.private_key_pem}"
  filename    = "ssh_key.pem"
  provisioner "local-exec" {
    command = "chmod 0600 ${local_file.ssh_key.filename}"
  }
}

resource "digitalocean_ssh_key" "default" {
  name       = "test key"
  public_key = "${tls_private_key.ssh_key.public_key_openssh}"
}

resource "digitalocean_droplet" "pharos_master" {
  count              = "${var.master_count}"
  image              = "${var.image}"
  name               = "${var.cluster_name}-master-${count.index}"
  region             = "${var.region}"
  size               = "${var.master_size}"
  private_networking = true
  ssh_keys           = ["${digitalocean_ssh_key.default.fingerprint}"]
}

resource "random_pet" "pharos_worker" {
  count              = "${var.worker_count}"
  keepers {
    region = "${var.region}"
  }
}

resource "digitalocean_droplet" "pharos_worker" {
  count              = "${var.worker_count}"
  image              = "${var.image}"
  name               = "${var.cluster_name}-${element(random_pet.pharos_worker.*.id, count.index)}"
  region             = "${var.region}"
  size               = "${var.worker_size}"
  private_networking = true
  ssh_keys           = ["${digitalocean_ssh_key.default.fingerprint}"]
}

resource "digitalocean_volume" "pharos_storage" {
  count                   = "${digitalocean_droplet.pharos_worker.count}"
  region                  = "${var.region}"
  name                    = "${element(digitalocean_droplet.pharos_worker.*.name, count.index)}"
  size                    = "${var.data_volume_size}"
}

resource "digitalocean_volume_attachment" "pharos_storage" {
  count                   = "${digitalocean_droplet.pharos_worker.count}"
  droplet_id              = "${element(digitalocean_droplet.pharos_worker.*.id, count.index)}"
  volume_id               = "${element(digitalocean_volume.pharos_storage.*.id, count.index)}"
}

output "pharos_hosts" {
  value = {
    masters = {
      address           = "${digitalocean_droplet.pharos_master.*.ipv4_address}"
      private_address   = "${digitalocean_droplet.pharos_master.*.ipv4_address_private}"
      role              = "master"
      user              = "root"
      ssh_key_path      = "./ssh_key.pem"
      ssh_proxy_command = "ssh -i ./ssh_key.pem -W %h:22 root@${digitalocean_droplet.pharos_worker.*.ipv4_address[0]}"

      label = {
        "beta.kubernetes.io/instance-type"         = "${var.worker_size}"
        "failure-domain.beta.kubernetes.io/region" = "${var.region}"
      }
    }

    workers = {
      address           = "${digitalocean_droplet.pharos_worker.*.ipv4_address}"
      private_address   = "${digitalocean_droplet.pharos_worker.*.ipv4_address_private}"
      role              = "worker"
      user              = "root"
      ssh_key_path      = "./ssh_key.pem"
      bastion = {
        address           = "${digitalocean_droplet.pharos_master.*.ipv4_address[0]}"
        ssh_key_path      = "./ssh_key.pem"
        user              = "root"
      }

      label = {
        "beta.kubernetes.io/instance-type"         = "${var.worker_size}"
        "failure-domain.beta.kubernetes.io/region" = "${var.region}"
      }
    }
  }
}
