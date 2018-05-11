resource "aws_security_group" "worker" {
  name        = "${var.cluster_name}"
  description = "pharos cluster workers"
  vpc_id      = "${aws_default_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "pharos_worker" {
  count = "${var.worker_count}"

  tags = "${map(
    "Name", "${var.cluster_name}-worker-${count.index + 1}",
    "${local.kube_cluster_tag}", "shared"
  )}"

  instance_type          = "${var.worker_type}"
  iam_instance_profile   = "${aws_iam_instance_profile.profile.name}"
  ami                    = "${data.aws_ami.ubuntu.id}"
  key_name               = "${var.ssh_key}"
  vpc_security_group_ids = ["${aws_security_group.common.id}", "${aws_security_group.worker.id}"]
  availability_zone      = "${data.aws_availability_zones.available.names[count.index % local.az_count]}"

  ebs_optimized = true

  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.worker_volume_size}"
  }
}

resource "aws_lb" "pharos_worker" {
  name               = "${var.cluster_name}-worker-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${data.aws_subnet_ids.default.ids}"]

  tags {
    Cluster = "${var.cluster_name}"
  }
}

resource "aws_lb_target_group" "pharos_worker_http" {
  name     = "${var.cluster_name}-http"
  port     = 80
  protocol = "TCP"
  vpc_id   = "${aws_default_vpc.default.id}"
}

resource "aws_lb_target_group" "pharos_worker_https" {
  name     = "${var.cluster_name}-https"
  port     = 443
  protocol = "TCP"
  vpc_id   = "${aws_default_vpc.default.id}"
}

resource "aws_lb_listener" "pharos_worker_http" {
  load_balancer_arn = "${aws_lb.pharos_worker.arn}"
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.pharos_worker_http.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "pharos_worker_https" {
  load_balancer_arn = "${aws_lb.pharos_worker.arn}"
  port              = 443
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.pharos_worker_https.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "pharos_worker_http" {
  count            = "${var.worker_count}"
  target_group_arn = "${aws_lb_target_group.pharos_worker_http.arn}"
  target_id        = "${element(aws_instance.pharos_worker.*.id, count.index)}"
  port             = 80
}

resource "aws_lb_target_group_attachment" "pharos_worker_https" {
  count            = "${var.worker_count}"
  target_group_arn = "${aws_lb_target_group.pharos_worker_https.arn}"
  target_id        = "${element(aws_instance.pharos_worker.*.id, count.index)}"
  port             = 443
}
