# frozen_string_literal: true

require "clamp"
require_relative "kupo/autoload"
require_relative "kupo/version"
require_relative "kupo/command"
require_relative "kupo/error"
require_relative "kupo/root_command"

module Kupo
  CRIO_VERSION = '1.9'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.9.5' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  DOCKER_VERSION = '1.13.1'
end
