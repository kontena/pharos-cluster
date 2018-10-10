# frozen_string_literal: true

require_relative 'os_release'
require_relative 'cpu_arch'

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
      attribute :container_runtime, Pharos::Types::Strict::String.default('docker')
      attribute :environment, Pharos::Types::Strict::Hash

      attr_accessor :os_release, :cpu_arch, :hostname, :api_endpoint, :private_interface_address, :checks, :resolvconf, :routes

      def to_s
        short_hostname || address
      end

      def short_hostname
        return nil unless hostname

        hostname.split('.').first
      end

      def api_address
        api_endpoint || address
      end

      def peer_address
        private_address || private_interface_address || address
      end

      def labels
        return @attributes[:labels] unless worker?

        @attributes[:labels] || { 'node-role.kubernetes.io/worker': "" }
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

        args += configurer(nil).kubelet_args

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

      # @param cidr [String]
      # @return [Array<Pharos::Configuration::Host::Route>]
      def overlapping_routes(cidr)
        routes.select{ |route| route.overlaps? cidr }
      end

      # @param ssh [Pharos::SSH::Client]
      def configurer(ssh)
        configurer = Pharos::Host::Configurer.config_for_os_release(os_release)
        configurer&.new(self, ssh)
      end
    end
  end
end
