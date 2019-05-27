# frozen_string_literal: true

Pharos.addon('kontena-stats') do
  prometheus_version = '2.9.2'
  node_exporter_version = '0.18.0'
  version "#{prometheus_version}+kontena.1"
  license 'Kontena License'
  priority 9

  Retention = custom_type {
    attribute :time, Pharos::Types::String
    attribute :size, Pharos::Types::String
  }

  Persistence = custom_type {
    attribute :enabled, Pharos::Types::Bool
  }

  config {
    attribute :replicas, Pharos::Types::Integer.default(1)
    attribute :tolerations, Pharos::Types::Array.default(proc { [] })
    attribute :node_selector, Pharos::Types::Hash.default(proc { {} })
    attribute :retention, Retention.default(proc { Retention.new(time: '90d', size: '1GB') })
    attribute :persistence, Persistence
    attribute :alert_managers, Pharos::Types::Array.default(proc { [] })
  }

  config_schema {
    optional(:replicas).filled(:int?)
    optional(:tolerations).each(:hash?)
    optional(:node_selector).filled(:hash?)
    optional(:retention).schema do
      required(:time).filled(:str?)
      required(:size).filled(:str?)
    end
    optional(:persistence).schema do
      required(:enabled).filled(:bool?)
    end
    optional(:alert_managers).each(:str?)
  }

  install {
    apply_resources(
      prometheus_version: prometheus_version,
      prometheus_pvc_size: prometheus_pvc_size,
      node_exporter_version: node_exporter_version
    )
    if config.persistence&.enabled
      logger.info "Calculated PVC size: #{prometheus_pvc_size}"
    end
  }

  # @return [String]
  def prometheus_pvc_size
    size, unit = config.retention.size.match(/^(\d+)(.+)/).captures
    size = (size.to_i * 1.25).ceil
    unit = unit.gsub(/B$/, 'i')
    "#{size}#{unit}"
  end
end
