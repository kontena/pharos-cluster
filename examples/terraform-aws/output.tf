output "pharos_api" {
  value = {
    endpoint = "${aws_lb.pharos_master.dns_name}"
  }
}

output "pharos_hosts" {
  value = {
    masters = {
      address         = "${aws_instance.pharos_master.*.public_ip}"
      private_address = "${aws_instance.pharos_master.*.private_ip}"
      role            = "master"
      user            = "ubuntu"
    }

    workers = {
      address         = "${aws_instance.pharos_worker.*.public_ip}"
      private_address = "${aws_instance.pharos_worker.*.private_ip}"
      role            = "worker"
      user            = "ubuntu"

      label = {
        ingress = "nginx"
      }
    }
  }
}
