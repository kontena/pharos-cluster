# frozen_string_literal: true

module Pharos
  module CommandOptions
    module FilteredHosts
      def self.included(base)
        base.prepend(InstanceMethods)
        base.options :load_config
        base.option ['-r', '--role'], 'ROLE', 'select a host by role'
        base.option ['-l', '--label'], 'LABEL=VALUE', 'select a host by label, can be specified multiple times', multivalued: true do |pair|
          key, value = pair.split('=', 2)
          signal_usage_error "invalid syntax for label : #{pair}, see --help for usage" if value.nil?
          { key: key, value: value }
        end
        base.option ['-a', '--address'], 'ADDRESS', 'select a host by public address'

        base.option ['-f', '--first'], :flag, 'only perform on the first matching host'
      end

      module InstanceMethods
        def complete_role
          "master worker"
        end

        private

        def filtered_hosts
          @filtered_hosts ||= Array(
            load_config.hosts.send(first? ? :find : :select) do |host|
              next if role && host.role != role
              next if address && host.address != address

              unless label_list.empty?
                next if host.labels.nil?
                next unless label_list.all? { |l| host.labels[l[:key]] == l[:value] }
              end

              true
            end
          ).tap do |result|
            signal_usage_error 'no host matched in configuration' if result.empty?
          end
        end
      end
    end
  end
end
