# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'
require_relative 'bastion'

require 'ipaddr'

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
      attribute :bastion, Pharos::Configuration::Bastion.optional.default(nil)

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint, :private_interface_address, :resolvconf, :routes, :config

      # @return [String]
      def to_s
        short_hostname || address
      end

      # @return [String,nil]
      def short_hostname
        return nil unless hostname

        hostname.split('.').first
      end

      # @return [Hash]
      def ssh_options
        {}.tap do |opts|
          opts[:keys] = [ssh_key_path] if ssh_key_path
          opts[:send_env] = [] # override default to not send LC_* envs
          opts[:proxycommand] = ssh_proxy_command if ssh_proxy_command
        end
      end

      # @return [Pharos::Transport::Gateway]
      def gateway
        @gateway ||= Pharos::Transport::Gateway.new(self)
      end

      # @return [Boolean]
      def gateway?
        !!@gateway
      end

      # @return [Hash] kubernetes config
      def kubeconfig
        cfg_file = transport.file('/etc/kubernetes/admin.conf')
        return nil unless cfg_file.exist?

        cfg = Pharos::Kube::Config.new(cfg_file.read)
        cfg.update_server_address(api_address)
        cfg.to_h
      end

      # @return [Boolean]
      def kube_client?
        !@kube_client.nil?
      end

      # @return [K8s::Client,nil]
      def kube_client
        return @kube_client if @kube_client

        cfg = kubeconfig
        return unless cfg

        @kube_gw = bastion&.host&.gateway || gateway
        @kube_gw_port = @kube_gw.open(api_address, 6443)

        @kube_client = Pharos::Kube.client('localhost', cfg, @kube_gw_port)
      end

      # @return [nil]
      def disconnect_kube_client
        return unless kube_client?

        @kube_client = nil
        @kube_gw.close(@kube_gw_port)
        @kube_gw_port = nil
        @kubw_gw = nil
      end

      # @return [Boolean]
      def local?
        IPAddr.new(address).loopback?
      end

      # Accessor to host transport which handles running commands and manipulating files on the
      # target host
      # @return [Pharos::Transport::Local,Pharos::Transport::SSH]
      def transport
        @transport ||= Pharos::Transport.for(self)
      end

      # @return [nil]
      def disconnect
        disconnect_kube_client if kube_client?
        transport.disconnect if transport.connected?
        gateway.shutdown! if gateway?

        nil
      end

      # @return [String]
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
        labels['node-role.kubernetes.io/worker'] = '' if worker?

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

      # @return [Boolean]
      def crio?
        container_runtime == 'cri-o'
      end

      # @return [Boolean]
      def docker?
        container_runtime == 'docker'
      end

      # @return [Boolean]
      def custom_docker?
        container_runtime == 'custom_docker'
      end

      # @return [Boolean]
      def new?
        !checks['kubelet_configured']
      end

      # @return [Boolean]
      def master_healthy?
        master? && master_sort_score.zero?
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

      # @return [Boolean]
      def master?
        role == 'master'
      end

      # @return [Boolean]
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
