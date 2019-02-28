# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateConfigurationChanges < Pharos::Phase
      title "Validate configuration changes"

      DEFAULT_PROC = proc { |key, old_val, new_val| raise Pharos::ConfigError, key => "can't change #{key} from #{old_val} to #{new_val}" }

      def call
        changed?('network', 'provider', &DEFAULT_PROC)
        changed?('network', 'service_cidr', &DEFAULT_PROC)
        changed?('network', 'pod_network_cidr', &DEFAULT_PROC)
      end

      def changed?(*config_keys)
        old_value = previous_config&.dig(*config_keys)
        new_value = @config&.dig(*config_keys)
        return false if old_value == new_value
        return true unless block_given?

        yield config_keys.map(&:to_s).join('.'), old_value, new_value
      end

      def previous_config
        cluster_context['previous-config']
      end
    end
  end
end
