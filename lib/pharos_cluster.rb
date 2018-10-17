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
  TELEMETRY_VERSION = '0.1.0'

  # @return [Boolean] true when running the OSS licensed version
  def self.oss?
    true
  end
end

unless ENV['PHAROS_DISABLE_NON_OSS']
  require 'pathname'
  non_oss_path = File.expand_path('../../non-oss', Pathname.new(__FILE__).realpath)
  $LOAD_PATH.unshift non_oss_path unless $LOAD_PATH.include?(non_oss_path)
  # rubocop:disable Lint/HandleExceptions
  begin
    require 'pharos_cluster_non_oss'
  rescue LoadError
  end
  # rubocop:enable Lint/HandleExceptions
end
