# frozen_string_literal: true

require 'ipaddr'

module Pharos
  module Configuration
    class Network < Pharos::Configuration::Struct
      class Weave < Pharos::Configuration::Struct
        attribute :trusted_subnets, Pharos::Types::Array.of(Pharos::Types::String)

        # @param routes [Array<Pharos::Configuration::Host::Routes>]
        # @return [Array<Pharos::Configuration::Host::Routes>]
        def self.filter_host_routes(routes)
          routes.reject{ |route|
            route.dev == 'weave'
          }
        end
      end

      class Calico < Pharos::Configuration::Struct
        attribute :ipip_mode, Pharos::Types::String.default('Always')
        attribute :nat_outgoing, Pharos::Types::Strict::Bool.default(true)

        # @param routes [Array<Pharos::Configuration::Host::Routes>]
        # @return [Array<Pharos::Configuration::Host::Routes>]
        def self.filter_host_routes(routes)
          routes.reject{ |route|
            route.proto == 'bird' || route.dev =~ /^cali/
          }
        end
      end

      class Custom < Pharos::Configuration::Struct
        attribute :manifest_path, Pharos::Types::String
        attribute :options, Pharos::Types::Hash

        # @param _routes [Array<Pharos::Configuration::Host::Routes>]
        # @return [Array<Pharos::Configuration::Host::Routes>]
        def self.filter_host_routes(_routes)
          # There's no way to validate routes for a custom CNI setup
          []
        end
      end

      class Firewalld < Pharos::Configuration::Struct
        attribute :enabled, Pharos::Types::Bool.default(false)
      end

      attribute :provider, Pharos::Types::String.default('weave')
      attribute :dns_replicas, Pharos::Types::Integer
      attribute :service_cidr, Pharos::Types::String.default('10.96.0.0/12')
      attribute :pod_network_cidr, Pharos::Types::String.default('10.32.0.0/12')
      attribute :firewalld, Firewalld
      attribute :weave, Weave
      attribute :calico, Calico
      attribute :custom, Custom

      # @return [String] 10.96.0.10
      def dns_service_ip
        (IPAddr.new(service_cidr) | 10).to_s
      end

      # @param routes [Array<Pharos::Configuration::Host::Routes>]
      # @return [Array<Pharos::Configuration::Host::Routes>]
      def filter_host_routes(routes)
        case provider
        when 'weave'
          Weave.filter_host_routes(routes)
        when 'calico'
          Calico.filter_host_routes(routes)
        when 'custom'
          Custom.filter_host_routes(routes)
        else
          fail
        end
      end
    end
  end
end
