#!/bin/sh

if [ "$(kubectl version --client --short)" != "Client Version: v${KUBE_VERSION}" ]; then
  /opt/kontena/bin/install-kube-bin.sh kubectl
fi
