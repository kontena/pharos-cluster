# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.10'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.10.2' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.1.12' }
  DOCKER_VERSION = '1.13.1'
  KUBELET_PROXY_VERSION = '0.3.5'

  def self.addon(name, &block)
    AddonManager.addons[name] = Class.new(Pharos::Addon, &block).tap do |addon|
      addon.source_location = block.source_location.first
      addon.name name
    end

    # Magic to create Pharos::Addons::IngressNginx etc so that specs still work
    Pharos::Addons.const_set(name.split(/[-_ ]/).map(&:capitalize).join, AddonManager.addons[name])
  end
end
