# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.10'
  CRICTL_VERSION = 'v1.0.0-beta.0'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.10.2' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.1.12' }
  DOCKER_VERSION = '1.13.1'
  KUBELET_PROXY_VERSION = '0.3.5'
end
