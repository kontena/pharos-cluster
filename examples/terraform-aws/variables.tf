variable "cluster_name" {
  default = "pharos"
}

variable "aws_region" {
  default = "eu-west-2"
}

variable "ssh_key" {
  description = "SSH key name"
}

variable "master_count" {
  default = 3
}

variable "worker_count" {
  default = 3
}

variable "master_type" {
  default = "m5.large"
}

variable "worker_type" {
  default = "m5.large"
}

variable "master_volume_size" {
  default = 100
}

variable "worker_volume_size" {
  default = 100
}
