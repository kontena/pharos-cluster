variable "auth_token" {
  description = "Packet authentication token"
}

variable "project_id" {
  description = "Packet project id"
}

variable "facility" {
  default = "ewr1"
}

variable "cluster_name" {
  default = "pharos"
}

variable "master_plan" {
  default = "baremetal_1"
}

variable "worker_plan" {
  default = "baremetal_1"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 2
}

provider "packet" {
  auth_token = "${var.auth_token}"
}

resource "packet_device" "pharos_master" {
  count            = "${var.master_count}"
  hostname         = "${var.cluster_name}-master-${count.index}"
  plan             = "${var.master_plan}"
  facility         = "${var.facility}"
  operating_system = "ubuntu_16_04"
  billing_cycle    = "hourly"
  project_id       = "${var.project_id}"
}

resource "packet_device" "pharos_worker" {
  count            = "${var.worker_count}"
  hostname         = "${var.cluster_name}-worker-${count.index}"
  plan             = "${var.worker_plan}"
  facility         = "${var.facility}"
  operating_system = "ubuntu_16_04"
  billing_cycle    = "hourly"
  project_id       = "${var.project_id}"
}

output "pharos_hosts" {
  value = {
    masters = {
      address         = "${packet_device.pharos_master.*.access_public_ipv4}"
      private_address = "${packet_device.pharos_master.*.access_private_ipv4}"
      role            = "master"
      user            = "root"

      label = {
        "beta.kubernetes.io/instance-type" = "${var.master_plan}"
        "failure-domain.beta.kubernetes.io/region" = "${var.facility}"
      }
    }

    workers = {
      address         = "${packet_device.pharos_worker.*.access_public_ipv4}"
      private_address = "${packet_device.pharos_worker.*.access_private_ipv4}"

      label = {
        "beta.kubernetes.io/instance-type" = "${var.worker_plan}"
        "failure-domain.beta.kubernetes.io/region" = "${var.facility}"
      }

      user = "root"
      role = "worker"
    }
  }
}
