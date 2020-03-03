# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CNI_VERSION = '0.7.5'
  COREDNS_VERSION = '1.6.5'
  DNS_NODE_CACHE_VERSION = '1.15.7'
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.3.10' }
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.17.3' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  KUBELET_PROXY_VERSION = '0.3.8'
end
