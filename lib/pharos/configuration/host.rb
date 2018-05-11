# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'

module Pharos
  module Configuration
    class Host < Dry::Struct
      constructor_type :schema

      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String
      attribute :private_interface, Pharos::Types::Strict::String
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :user, Pharos::Types::Strict::String.default('ubuntu')
      attribute :ssh_key_path, Pharos::Types::Strict::String.default('~/.ssh/id_rsa')
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')
      attribute :master_taint, Pharos::Types::Strict::Bool.default(true)

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint, :private_interface_address, :checks

      def to_s
        address
      end

      def api_address
        api_endpoint || address
      end

      def peer_address
        private_address || private_interface_address || address
      end

      def kubelet_args(local_only: false)
        args = []

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=/var/run/crio/crio.sock'
        end

        if local_only
          args << "--pod-manifest-path=/etc/kubernetes/manifests/"
          args << "--cadvisor-port=0"
          args << "--address=127.0.0.1"
        else
          args << "--node-ip=#{peer_address}"
          args << "--hostname-override=#{hostname}"
        end

        args
      end

      def crio?
        container_runtime == 'cri-o'
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
    end
  end
end
