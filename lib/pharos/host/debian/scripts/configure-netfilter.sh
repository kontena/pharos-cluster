#!/bin/bash

set -e

if cat /proc/1/environ | grep "container=docker" ; then
  exit 0
fi

/sbin/modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
echo "net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/99-net-bridge.conf
systemctl restart procps
