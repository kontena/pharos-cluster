provider "aws" {
  region = "${var.aws_region}"
}

data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_subnet_ids" "default" {
  vpc_id = "${aws_default_vpc.default.id}"
}

resource "aws_default_vpc" "default" {}

resource "aws_security_group" "common" {
  name        = "${var.cluster_name}-common"
  description = "pharos cluster common rules"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 10250
    to_port   = 10250
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 6783
    to_port   = 6784
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 6784
    to_port   = 6784
    protocol  = "udp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  az_count         = "${length(data.aws_availability_zones.available.names)}"
  kube_cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"
}
