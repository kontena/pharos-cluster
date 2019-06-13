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
  sensitive_content     = "${tls_private_key.ssh_key.private_key_pem}"
  filename    = "${path.module}/ssh_key.pem"
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
  tags               = ["e2e", "airgap"]
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
  tags               = ["e2e", "airgap"]
}

resource "digitalocean_droplet" "pharos_worker_up" {
  count              = "1"
  image              = "${var.image}"
  name               = "${var.cluster_name}-worker-up"
  region             = "${var.region}"
  size               = "${var.worker_size}"
  private_networking = true
  ssh_keys           = ["${digitalocean_ssh_key.default.fingerprint}"]
  tags               = ["e2e", "airgap"]
}

output "pharos_cluster" {
  value = {
    name = "${var.cluster_name}"
  }
}

output "worker_up" {
  value = {
    address           = "${digitalocean_droplet.pharos_worker_up.*.ipv4_address}"
  }
}

output "pharos_hosts" {
  value = {
    masters = {
      address           = "${digitalocean_droplet.pharos_master.*.ipv4_address}"
      private_address   = "${digitalocean_droplet.pharos_master.*.ipv4_address_private}"
      role              = "master"
      user              = "root"
      ssh_key_path      = "${local_file.ssh_key.filename}"

      label = {
        "beta.kubernetes.io/instance-type"         = "${var.worker_size}"
        "failure-domain.beta.kubernetes.io/region" = "${var.region}"
      }

      environment = {
        "HTTP_PROXY" = "http://10.133.37.156:8888"
        "HTTPS_PROXY" = "http://10.133.37.156:8888"
        "http_proxy" = "http://10.133.37.156:8888"
        "https_proxy" = "http://10.133.37.156:8888"
        "NO_PROXY" = "localhost,0,1,2,3,4,5,6,7,8,9"
        "no_proxy" = "localhost,0,1,2,3,4,5,6,7,8,9"
      }
    }

    workers = {
      address           = "${digitalocean_droplet.pharos_worker.*.ipv4_address}"
      private_address   = "${digitalocean_droplet.pharos_worker.*.ipv4_address_private}"
      role              = "worker"
      user              = "root"
      ssh_key_path      = "${local_file.ssh_key.filename}"
      bastion = {
        address           = "${digitalocean_droplet.pharos_master.*.ipv4_address[0]}"
        ssh_key_path      = "${local_file.ssh_key.filename}"
        user              = "root"
      }

      label = {
        "beta.kubernetes.io/instance-type"         = "${var.worker_size}"
        "failure-domain.beta.kubernetes.io/region" = "${var.region}"
      }

      environment = {
        "HTTP_PROXY" = "http://10.133.37.156:8888"
        "HTTPS_PROXY" = "http://10.133.37.156:8888"
        "http_proxy" = "http://10.133.37.156:8888"
        "https_proxy" = "http://10.133.37.156:8888"
        "NO_PROXY" = "localhost,0,1,2,3,4,5,6,7,8,9"
        "no_proxy" = "localhost,0,1,2,3,4,5,6,7,8,9"
      }
    }
  }
}
