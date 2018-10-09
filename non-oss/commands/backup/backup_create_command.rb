# frozen_string_literal: true

require "k8s-client"
require_relative 'client_helper'

module Pharos
  class BackupCreateCommand < Pharos::Command
    include ClientHelper

    banner "Create a backup of cluster resources"

    option "--include-namespace", "INCLUDE_NS", "namespace(s) to include in the backup", multivalued: true, attribute_name: :included_namespaces
    option "--exclude-namespace", "EXCLUDE_NS", "namespace(s) to exclude from the backup", multivalued: true, attribute_name: :excluded_namespaces
    option "--label-selector", "LABEL_SELECTOR", "Select backed up object by labels. Format: label=value", multivalued: true
    option "--ttl", "TTL", "Backup time-to-live. E.g. 24h", default: '720h'
    option "--[no-]include-cluster-resources", :flag, "Include cluster-wide resources into backup", default: true

    parameter "NAME", "Name of the backup"

    def execute
      backup = {
        apiVersion: 'ark.heptio.com/v1',
        kind: 'Backup',
        metadata: {
          name: name,
          namespace: 'kontena-backup',
          labels: {},
          annotations: {
            'pharos.kontena.io/version': Pharos::VERSION
          }
        },
        spec: {
          includedNamespaces: included_namespaces,
          excludedNamespaces: excluded_namespaces,
          snapshotVolumes: nil,
          includeClusterResources: include_cluster_resources?
        }
      }

      backup[:spec][:ttl] = ttl if ttl # Ark chokes on ttl being nil...
      backup[:spec][:labelSelector] = build_label_selector unless label_selector_list&.empty?

      logger.debug { "Creating backup: #{backup}" }
      client.create_resource(K8s::Resource.new(backup))

      puts "Backup #{pastel.cyan(name)} created succesfully" if $stdout.tty?
    rescue K8s::Error::Conflict
      raise unless ENV['DEBUG'].to_s.empty?
      warn pastel.red("ERROR: Backup named #{name} already exists") if $stdout.tty?
      exit 1
    rescue StandardError => exc
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end

    def build_label_selector
      selector = {
        matchLabels: {}
      }
      label_selector_list.each{ |ls|
        k, v = ls.split('=', 2)
        selector[:matchLabels][k.to_sym] = v
      }
      selector
    end
  end
end
