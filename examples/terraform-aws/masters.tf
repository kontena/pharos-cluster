resource "aws_security_group" "master" {
  name        = "${var.cluster_name}-masters"
  description = "pharos cluster masters"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "pharos_master" {
  count = "${var.master_count}"

  tags = "${map(
    "Name", "${var.cluster_name}-master-${count.index + 1}",
    "${local.kube_cluster_tag}", "owned"
  )}"

  instance_type          = "${var.master_type}"
  iam_instance_profile   = "${aws_iam_instance_profile.profile.name}"
  ami                    = "${data.aws_ami.ubuntu.id}"
  key_name               = "${var.ssh_key}"
  vpc_security_group_ids = ["${aws_security_group.common.id}", "${aws_security_group.master.id}"]
  availability_zone      = "${data.aws_availability_zones.available.names[count.index % local.az_count]}"

  ebs_optimized = true

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.master_volume_size}"
  }
}

resource "aws_lb" "pharos_master" {
  name               = "${var.cluster_name}-master-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${data.aws_subnet_ids.default.ids}"]

  tags {
    Cluster = "${var.cluster_name}"
  }
}

resource "aws_lb_target_group" "pharos_master_api" {
  name     = "${var.cluster_name}-api"
  port     = 6443
  protocol = "TCP"
  vpc_id   = "${aws_default_vpc.default.id}"
}

resource "aws_lb_listener" "pharos_master_api" {
  load_balancer_arn = "${aws_lb.pharos_master.arn}"
  port              = 6443
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.pharos_master_api.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "pharos_master_api" {
  count            = "${var.master_count}"
  target_group_arn = "${aws_lb_target_group.pharos_master_api.arn}"
  target_id        = "${element(aws_instance.pharos_master.*.id, count.index)}"
  port             = 6443
}
