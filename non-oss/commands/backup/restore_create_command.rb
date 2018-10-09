# frozen_string_literal: true

require_relative 'client_helper'

module Pharos
  class RestoreCreateCommand < Pharos::Command
    include ClientHelper

    banner "Restore cluster resources"

    parameter "NAME", "Name of the backup to restore"

    option "--include-namespace", "INCLUDE_NS", "namespace(s) to include in the restore", multivalued: true, attribute_name: :included_namespaces
    option "--exclude-namespace", "EXCLUDE_NS", "namespace(s) to exclude from the restore", multivalued: true, attribute_name: :excluded_namespaces
    option "--[no-]include-cluster-resources", :flag, "restore cluster-wide resources from the backup", default: true

    def execute
      restore = {
        apiVersion: 'ark.heptio.com/v1',
        kind: 'Restore',
        metadata: {
          name: "#{name}-#{Time.now.utc.to_i}", # So that each restore gets unique name
          namespace: 'kontena-backup',
          labels: {}
        },
        spec: {
          backupName: name,
          includedNamespaces: included_namespaces,
          excludedNamespaces: excluded_namespaces,
          restorePVs: nil,
          includeClusterResources: include_cluster_resources?
        }
      }
      logger.debug { "Creating restore: #{restore}" }
      client.create_resource(K8s::Resource.new(restore))

      puts "Restore #{pastel.cyan(name)} created succesfully" if $stdout.tty?
    rescue StandardError => exc
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
