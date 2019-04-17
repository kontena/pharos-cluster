# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CNI_VERSION = '0.7.5'
  COREDNS_VERSION = '1.3.1'
  CRIO_VERSION = '1.13.4'
  DNS_NODE_CACHE_VERSION = '1.15.1'
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.3.10' }
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.14.1' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  KUBELET_PROXY_VERSION = '0.3.7'
  TELEMETRY_VERSION = '0.2.0'
end

require "pharos_non_oss" if $LOAD_PATH.any? { |path| path.end_with?('non-oss') }
