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
  default = "baremetal_0"
}

variable "worker_plan" {
  default = "baremetal_0"
}

variable "master_count" {
  default = 1
}

variable "worker_count" {
  default = 2
}

variable "host_os" {
  default = "ubuntu_16_04"
}

variable "container_runtime" {
  default = "docker"
}

variable "bgp_address_pool" {
  default = ""
}

provider "packet" {
  auth_token = var.auth_token
}

data "template_file" "packet_cc_secret" {
  template = "${file("${path.module}/packet-cloud-config-secret.yaml.tpl")}"
  vars = {
    api_key = base64encode(var.auth_token)
    project_id = base64encode(var.project_id)
  }
}

resource "local_file" "packet_cc_secret" {
  content     = data.template_file.packet_cc_secret.rendered
  filename = "${path.module}/.packet-cc-secret.${var.cluster_name}.yaml"
}

resource "packet_device" "pharos_master" {
  count            = var.master_count
  hostname         = "${var.cluster_name}-master-${count.index}"
  plan             = var.master_plan
  facilities       = [var.facility]
  operating_system = var.host_os
  billing_cycle    = "hourly"
  project_id       = var.project_id
  tags             = ["master"]
}

resource "packet_device" "pharos_worker" {
  count            = var.worker_count
  hostname         = "${var.cluster_name}-worker-${count.index}"
  plan             = var.worker_plan
  facilities       = [var.facility]
  operating_system = var.host_os
  billing_cycle    = "hourly"
  project_id       = var.project_id
  tags             = ["worker"]
}

resource "packet_bgp_session" "pharos_bgb_session" {
  count            = var.worker_count
  device_id        = packet_device.pharos_worker[count.index].id
  address_family   = "ipv4"
}

output "pharos_cluster" {
  value = {
    cloud = {
      provider = "packet"
      config = local_file.packet_cc_secret.filename
    }
    hosts = [
      for host in concat(packet_device.pharos_master, packet_device.pharos_worker)  : {
        address           = host.access_public_ipv4
        private_address   = host.access_private_ipv4
        role              = host.tags[0]
        user              = "root"
        container_runtime = "${var.container_runtime}"
      }
    ]
    addons = {
      ingress-nginx = {
        enabled = true
        kind: "Deployment"
      }
      kontena-network-lb = {
        enabled = var.bgp_address_pool != "" ? true : false
        address_pools = [
          {
            name = "default"
            protocol = "bgp"
            addresses = [var.bgp_address_pool]
          }
        ]
        peers = [
          for host in packet_device.pharos_worker : {
            peer_address = host.network[2].gateway
            peer_asn = 65530
            my_asn = 65000
            node_selectors = [
              {
                match-expression = [
                  {
                    key = "kubernetes.io/hostname"
                    operator = "In"
                    values = [host.hostname]
                  }
                ]
              }
            ]
          }
        ]
      }
      kontena-storage = {
        enabled = true
        data_dir = "/var/lib/kontena-storage"
        storage = {
          use_all_nodes = true
          directories = [
            {
              path = "/mnt/data1"
            }
          ]
        }
      }
    }
  }
}
