# frozen_string_literal: true

require "clamp"
require_relative "pharos/autoload"
require_relative "pharos/version"
require_relative "pharos/command"
require_relative "pharos/error"
require_relative "pharos/root_command"

module Pharos
  CRIO_VERSION = '1.11.6'
  KUBE_VERSION = ENV.fetch('KUBE_VERSION') { '1.11.3' }
  KUBEADM_VERSION = ENV.fetch('KUBEADM_VERSION') { KUBE_VERSION }
  ETCD_VERSION = ENV.fetch('ETCD_VERSION') { '3.2.18' }
  KUBELET_PROXY_VERSION = '0.3.7'
  COREDNS_VERSION = '1.1.3'

  # @param name [String]
  # @return [Pharos::Addon]
  def self.addon(name, &block)
    klass = Class.new(Pharos::Addon, &block).tap do |addon|
      addon.addon_location = File.dirname(block.source_location.first)
      addon.addon_name = name
    end

    # Magic to create Pharos::Addons::IngressNginx etc so that specs still work
    Pharos::Addons.const_set(name.split(/[-_ ]/).map(&:capitalize).join, klass)
    Pharos::AddonManager.addons << klass
    klass
  end
end
