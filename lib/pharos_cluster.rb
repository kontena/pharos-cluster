# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.11.1'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.11.1' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.2.18' }
  KUBELET_PROXY_VERSION = '0.3.6'
  COREDNS_VERSION = '1.1.3'
end
