# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'
require_relative 'bastion'

require 'net/ssh'
require 'net/ssh/proxy/jump'

module Pharos
  module Configuration
    class Host < Pharos::Configuration::Struct
      class ResolvConf < Pharos::Configuration::Struct
        attribute :nameserver_localhost, Pharos::Types::Strict::Bool
        attribute :systemd_resolved_stub, Pharos::Types::Strict::Bool
      end

      class Route < Pharos::Configuration::Struct
        ROUTE_REGEXP = %r(^((?<type>\S+)\s+)?(?<prefix>default|[0-9./]+)(\s+via (?<via>\S+))?(\s+dev (?<dev>\S+))?(\s+proto (?<proto>\S+))?(\s+(?<options>.+))?$)

        # @param line [String]
        # @return [Pharos::Configuration::Host::Route]
        # @raise [RuntimeError] invalid route
        def self.parse(line)
          fail "Unmatched ip route: #{line.inspect}" unless match = ROUTE_REGEXP.match(line.strip)

          captures = Hash[match.named_captures.map{ |k, v| [k.to_sym, v] }.reject{ |_k, v| v.nil? }]

          new(raw: line.strip, **captures)
        end

        attribute :raw, Pharos::Types::Strict::String
        attribute :type, Pharos::Types::Strict::String.optional
        attribute :prefix, Pharos::Types::Strict::String
        attribute :via, Pharos::Types::Strict::String.optional
        attribute :dev, Pharos::Types::Strict::String.optional
        attribute :proto, Pharos::Types::Strict::String.optional
        attribute :options, Pharos::Types::Strict::String.optional

        def to_s
          @raw
        end

        # @return [Boolean]
        def overlaps?(cidr)
          # special-case the default route and ignore it
          return nil if prefix == 'default'

          route_prefix = IPAddr.new(prefix)
          cidr = IPAddr.new(cidr)

          route_prefix.include?(cidr) || cidr.include?(route_prefix)
        end
      end

      attribute :address, Pharos::Types::Strict::String
      attribute :private_address, Pharos::Types::Strict::String.optional.default(nil)
      attribute :private_interface, Pharos::Types::Strict::String.optional.default(nil)
      attribute :role, Pharos::Types::Strict::String
      attribute :labels, Pharos::Types::Strict::Hash
      attribute :taints, Pharos::Types::Strict::Array.of(Pharos::Configuration::Taint)
      attribute :user, Pharos::Types::Strict::String
      attribute :ssh_key_path, Pharos::Types::Strict::String
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
        address == '127.0.0.1'
      end

      def transport(**options)
        @transport ||= local? ? Pharos::LocalClient.new(**options) : ssh(**options)
      end

      # param options [Hash] extra options for the SSH client, see Net::SSH#start
      def ssh(**options)
        return @ssh if @ssh

        opts = {}
        opts[:keys] = [ssh_key_path] if ssh_key_path
        opts[:send_env] = [] # override default to not send LC_* envs
        opts[:proxy] = Net::SSH::Proxy::Command.new(ssh_proxy_command) if ssh_proxy_command
        opts[:bastion] = bastion if bastion
        @ssh = Pharos::SSH::Client.new(address, user, **opts.merge(options)).tap(&:connect)
      rescue StandardError
        @ssh = nil
        raise
      end

      def ssh?
        @ssh && !@ssh.closed?
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
      # @return [Array<Pharos::Configuration::Host::Route>]
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

      # @param prefix [String] tempfile filename prefix (default "pharos")
      # @param content [String,IO] initial file content, default blank
      # @return [Pharos::SSH::Tempfile]
      # @yield [Pharos::SSH::Tempfile]
      def tempfile(prefix: "pharos", content: nil, &block)
        transport.tempfile(prefix: prefix, content: content, &block)
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @return [Pharos::Command::Result]
      def exec(cmd, **options)
        transport.exec(cmd, **options)
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @raise [Pharos::SSH::RemoteCommand::ExecError,Pharos::SSH::LocalCommand::ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        transport.exec!(cmd, **options)
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @return [Boolean]
      def exec?(cmd, **options)
        transport.exec?(cmd, **options)
      end

      # @param name [String] name of script
      # @param env [Hash] environment variables hash
      # @param path [String] real path to file, defaults to script
      # @raise [Pharos::SSH::RemoteCommand::ExecError,Pharos::SSH::LocalCommand::ExecError]
      # @return [String] stdout
      def exec_script!(name, env: {}, path: nil, **options)
        transport.exec_script!(name, env: env, path: path, **options)
      end

      # @param path [String]
      # @return [Pharos::SSH::RemoteFile]
      def file(path)
        transport.file(path)
      end

      # @return [Boolean] transport connected?
      def connected?
        transport.connected?
      end

      # Disconnect transport
      # @return [Boolean]
      def disconnect
        transport.disconnect
      end
    end
  end
end
