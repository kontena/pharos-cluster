# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.13.1'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.13.3' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.2.24' }
  KUBELET_PROXY_VERSION = '0.3.7'
  COREDNS_VERSION = '1.2.2'
  TELEMETRY_VERSION = '0.2.0'
end

require "pharos_non_oss" if $LOAD_PATH.any? { |path| path.end_with?('non-oss') }
