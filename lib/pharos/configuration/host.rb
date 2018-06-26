# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'

module Pharos
  module Configuration
    class Host < Dry::Struct
      constructor_type :schema

      class ResolvConf < Dry::Struct
        attribute :nameserver_localhost, Pharos::Types::Strict::Bool
        attribute :systemd_resolved_stub, Pharos::Types::Strict::Bool
      end

      class Route < Dry::Struct
        attribute :type, Pharos::Types::Strict::String.optional
        attribute :prefix, Pharos::Types::Strict::String
        attribute :via, Pharos::Types::Strict::String.optional
        attribute :dev, Pharos::Types::Strict::String.optional
        attribute :proto, Pharos::Types::Strict::String.optional
        attribute :options, Pharos::Types::Strict::String.optional
      end

      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String
      attribute :private_interface, Pharos::Types::Strict::String
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :taints, Pharos::Types::Strict::Array.of(Pharos::Configuration::Taint)
      attribute :user, Pharos::Types::Strict::String.default('ubuntu')
      attribute :ssh_key_path, Pharos::Types::Strict::String.default('~/.ssh/id_rsa')
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')
      attribute :http_proxy, Pharos::Types::Strict::String

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint, :private_interface_address, :checks, :resolvconf, :routes

      def to_s
        address
      end

      def api_address
        api_endpoint || address
      end

      def peer_address
        private_address || private_interface_address || address
      end

      def kubelet_args(local_only: false, cloud_provider: nil)
        args = []

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=unix:///var/run/crio/crio.sock'
        end

        if local_only
          args << "--pod-manifest-path=/etc/kubernetes/manifests/"
          args << "--cadvisor-port=0"
          args << "--address=127.0.0.1"
        else
          args << "--node-ip=#{peer_address}" if cloud_provider.nil?
          args << "--hostname-override=#{hostname}"
        end

        args
      end

      def crio?
        container_runtime == 'cri-o'
      end

      def docker?
        container_runtime == 'docker'
      end

      # @return [Integer]
      def master_sort_score
        if checks['api_healthy']
          0
        elsif checks['kubelet_configured']
          1
        else
          2
        end
      end

      # @return [Integer]
      def etcd_sort_score
        if checks['etcd_healthy']
          0
        elsif checks['etcd_ca_exists']
          1
        else
          2
        end
      end

      def master?
        role == 'master'
      end

      def worker?
        role == 'worker'
      end

      # @param ssh [Pharos::SSH::Client]
      def configurer(ssh)
        configurer = Pharos::Host::Configurer.config_for_os_release(os_release)
        configurer&.new(self, ssh)
      end
    end
  end
end
