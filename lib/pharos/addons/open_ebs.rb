# frozen_string_literal: true

module Pharos
  module Addons
    class OpenEbs < Pharos::Addon
      name 'openebs'
      version '0.5.3'
      license 'Apache License 2.0'

      struct {
        attribute :default_replicas, Pharos::Types::Int
        attribute :default_capacity, Pharos::Types::String
        attribute :default_class, Pharos::Types::Bool
      }

      schema {
        optional(:default_replicas).filled(:int?)
        optional(:default_capacity).filled(:str?)
        optional(:default_class).filled(:bool?)
      }

      def validate
        super
        raise Pharos::InvalidAddonError, "Cannot set more replicas than workers" if config.default_replicas && config.default_replicas > cluster_config.worker_hosts.count
      end

      def default_replica_count
        cluster_config.worker_hosts.count < 3 ? cluster_config.worker_hosts.count : 3
      end

      def install
        apply_stack(
          default_replicas: config.default_replicas || default_replica_count,
          default_capacity: config.default_capacity || '5G',
          is_default_class: config.default_class == true
        )
      end
    end
  end
end
