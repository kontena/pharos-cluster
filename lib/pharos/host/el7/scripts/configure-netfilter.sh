#!/bin/bash

set -e

modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
echo "net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/99-net-bridge.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-net-bridge.conf
sysctl --system
