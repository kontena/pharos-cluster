#!/bin/bash

set -e

mkdir -p /etc/kupo/etcd
cat <<EOF >/etc/kupo/etcd/ca-certificate.pem
<%= ca_certificate %>
EOF
cat <<EOF >/etc/kupo/etcd/certificate.pem
<%= certificate %>
EOF
cat <<EOF >/etc/kupo/etcd/certificate-key.pem
<%= certificate_key %>
EOF
