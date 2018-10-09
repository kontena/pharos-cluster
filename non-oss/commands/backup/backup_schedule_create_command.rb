# frozen_string_literal: true

require_relative 'client_helper'

module Pharos
  class BackupScheduleCreateCommand < Pharos::BackupCreateCommand
    include ClientHelper

    banner "Create a backup of cluster resources"

    option "--include-namespace", "INCLUDE_NS", "namespace(s) to include in the backup", multivalued: true, attribute_name: :included_namespaces
    option "--exclude-namespace", "EXCLUDE_NS", "namespace(s) to exclude from the backup", multivalued: true, attribute_name: :excluded_namespaces
    option "--label-selector", "LABEL_SELECTOR", "Select backed up object by labels. Format: label=value", multivalued: true
    # TODO Should we add some default ttl, like 720h (1 month)???
    option "--ttl", "TTL", "Backup time-to-live. E.g. 24h"
    option "--[no-]include-cluster-resources", :flag, "Include cluster-wide resources into backup", default: true
    option "--schedule", "SCHEDULE", "Schedule of the backup. 5 field cron notation", required: true

    parameter "NAME", "Name of the backup"

    def execute

      schedule_resource = K8s::Resource.new({
        apiVersion: 'ark.heptio.com/v1',
        kind: 'Schedule',
        metadata: {
          name: name,
          namespace: 'kontena-backup',
          labels: {},
          annotations: {
            'pharos.kontena.io/version': Pharos::VERSION
          }
        },
        spec: {
          schedule: schedule,
          template: {
            includedNamespaces: included_namespaces,
            excludedNamespaces: excluded_namespaces,
            snapshotVolumes: nil,
            includeClusterResources: include_cluster_resources?
          }
        }
      })


      backup[:spec][:template][:ttl] = ttl if ttl # Ark chokes on ttl being nil...
      backup[:spec][:template][:labelSelector] = build_label_selector unless label_selector_list&.empty?

      logger.debug { "Creating schedule: #{schedule_resource.to_h}" }
      client.create_resource(schedule_resource)

      puts "Backup schedule #{pastel.cyan(name)} created succesfully" if $stdout.tty?
    rescue K8s::Error::Conflict
      raise unless ENV['DEBUG'].to_s.empty?
      warn pastel.red("ERROR: Schedule named #{name} already exists") if $stdout.tty?
      exit 1
    rescue StandardError => exc
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
