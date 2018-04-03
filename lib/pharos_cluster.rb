# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.9'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.9.6' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  DOCKER_VERSION = '1.13.1'
end
