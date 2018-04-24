# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'

module Pharos
  module Configuration
    class Host < Dry::Struct
      constructor_type :schema

      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :user, Pharos::Types::Strict::String.default('ubuntu')
      attribute :ssh_key_path, Pharos::Types::Strict::String.default('~/.ssh/id_rsa')
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint

      def to_s
        address
      end

      def api_address
        api_endpoint || address
      end

      def peer_address
        private_address || address
      end

      def kubelet_args(local_only: false)
        args = []
        node_ip = private_address.nil? ? address : private_address

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=/var/run/crio/crio.sock'
        end

        if local_only
          args << "--pod-manifest-path=/etc/kubernetes/manifests/"
          args << "--read-only-port=0"
          args << "--cadvisor-port=0"
          args << "--address=127.0.0.1"
        else
          args << '--read-only-port=0'
          args << "--node-ip=#{node_ip}"
          args << "--hostname-override=#{hostname}"
        end

        args
      end

      def crio?
        container_runtime == 'cri-o'
      end
    end
  end
end
