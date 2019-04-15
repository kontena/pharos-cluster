# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'
require_relative 'bastion'
require_relative '../transport'

require 'ipaddr'
require 'resolv'

module Pharos
  module Configuration
    class Host < Pharos::Configuration::Struct
      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String.optional.default(nil)
      attribute :private_interface, Pharos::Types::Strict::String.optional.default(nil)
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :taints, Pharos::Types::Strict::Array.of(Pharos::Configuration::Taint)
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
      attribute :ssh_port, Pharos::Types::Strict::Integer.default(22)
      attribute :ssh_proxy_command, Pharos::Types::Strict::String
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')
      attribute :environment, Pharos::Types::Strict::Hash
      attribute :bastion, Pharos::Configuration::Bastion

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint, :private_interface_address, :resolvconf, :routes, :config

      def to_s
        short_hostname || address
      end

      def short_hostname
        return nil unless hostname

        hostname.split('.').first
      end

      def local?
        ip_address = Resolv.getaddress(address)
        IPAddr.new(ip_address).loopback?
      rescue Resolv::ResolvError, IPAddr::InvalidAddressError
        false
      end

      # Accessor to host transport which handles running commands and manipulating files on the
      # target host
      # @return [Pharos::Transport::Local,Pharos::Transport::SSH]
      def transport
        @transport ||= Pharos::Transport.for(self)
      end

      def api_address
        api_endpoint || address
      end

      # @return [String]
      def peer_address
        private_address || private_interface_address || address
      end

      # @param host [Pharos::Configuration::Host]
      # @return [String]
      def peer_address_for(host)
        if region == host.region
          peer_address
        else
          address
        end
      end

      # @return [String]
      def region
        labels['failure-domain.beta.kubernetes.io/region'] || 'unknown'
      end

      # @return [Hash]
      def labels
        labels = @attributes[:labels] || {}

        labels['node-address.kontena.io/external-ip'] = address
        labels['node-role.kubernetes.io/worker'] = '' if worker? && !labels.find{ |k, _| k.to_s.start_with?("node-role.kubernetes.io") }

        labels
      end

      # @return [Hash]
      def checks
        @checks ||= {}
      end

      # @param local_only [Boolean]
      # @param cloud_provider [String, NilClass]
      # @return [Array<String>]
      def kubelet_args(local_only: false, cloud_provider: nil)
        args = []

        args << "--rotate-server-certificates"

        if crio?
          args << '--container-runtime=remote'
          args << '--runtime-request-timeout=15m'
          args << '--container-runtime-endpoint=/var/run/crio/crio.sock' # see: https://github.com/kubernetes/kubernetes/issues/71712
        end

        if local_only
          args << "--pod-manifest-path=/etc/kubernetes/manifests/"
          args << "--address=127.0.0.1"
        else
          args << "--node-ip=#{peer_address}" if cloud_provider.nil?
          args << "--hostname-override=#{hostname}"
        end

        args += configurer.kubelet_args

        args
      end

      def crio?
        container_runtime == 'cri-o'
      end

      def docker?
        container_runtime == 'docker'
      end

      def custom_docker?
        container_runtime == 'custom_docker'
      end

      def new?
        !checks['kubelet_configured']
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

      # @param cidr [String]
      # @return [Array<Pharos::Configuration::Route>]
      def overlapping_routes(cidr)
        routes.select{ |route| route.overlaps? cidr }
      end

      # @return [NilClass,Pharos::Host::Configurer]
      def configurer
        return @configurer if @configurer
        raise "Os release not set" unless os_release&.id

        @configurer = Pharos::Host::Configurer.for_os_release(os_release)&.new(self)
      end

      # @param bastion [Pharos::Configuration::Bastion]
      def configure_bastion(bastion)
        return if self.bastion

        attributes[:bastion] = bastion
      end
    end
  end
end
