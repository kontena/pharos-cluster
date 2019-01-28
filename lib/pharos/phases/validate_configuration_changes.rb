# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateConfigurationChanges < Pharos::Phase
      title "Validate configuration changes"

      DEFAULT_PROC = proc { |key, old_val, new_val| raise Pharos::ConfigError, key => "can't change #{key} from #{old_val} to #{new_val}" }

      def call
        changed?('network.provider', &DEFAULT_PROC)
        changed?('network.service_cidr', &DEFAULT_PROC)
        changed?('network.pod_network_cidr', &DEFAULT_PROC)
      end

      def changed?(config_key_path)
        old_value = string_dig(config_key_path, previous_config)
        new_value = string_dig(config_key_path, @config)
        return false if old_value == new_value
        return true unless block_given?

        yield config_key_path, old_value, new_value
      end

      def string_dig(string, source)
        string.to_s.split('.').inject(source) { |memo, item| memo.send(item.to_sym) if memo.respond_to?(item.to_sym) }
      end

      def previous_config
        cluster_context['previous-config']
      end
    end
  end
end
