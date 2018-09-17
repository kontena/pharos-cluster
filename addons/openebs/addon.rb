# frozen_string_literal: true

Pharos.addon 'openebs' do
  version '0.6.0'
  license 'Apache License 2.0'

  default_class_opts = {
    default_class: false,
    capacity: '5G'
  }.freeze

  default_storage_path = '/var/openebs'

  default_pool_opts = {
    path: default_storage_path
  }.freeze

  config {
    attribute :default_storage_class, Pharos::Types::Hash.default(default_class_opts)
    attribute :default_storage_pool, Pharos::Types::Hash.default(default_pool_opts)
    attribute :default_replica_node_selector, Pharos::Types::String
    attribute :default_controller_node_selector, Pharos::Types::String
  }

  config_schema {
    optional(:default_storage_class).schema do
      optional(:default_class).filled(:bool?)
      optional(:capacity).filled(:str?)
      optional(:replicas).filled(:int?)
    end

    optional(:default_storage_pool).schema do
      optional(:path).filled(:str?)
    end

    optional(:default_replica_node_selector).filled(:str?)
    optional(:default_controller_node_selector).filled(:str?)
  }

  install {
    apply_resources(
      default_replicas: config.default_storage_class[:replicas] || default_replica_count,
      default_capacity: config.default_storage_class[:capacity] || '5G',
      is_default_class: config.default_storage_class[:default_class] == true,
      default_storage_pool_path: config.default_storage_pool[:path],
      default_replica_node_selector: config.default_replica_node_selector,
      default_controller_node_selector: config.default_controller_node_selector
    )
  }

  def validate
    super
    raise Pharos::InvalidAddonError, "Cannot set more replicas than workers" if config.default_storage_class[:replicas] && config.default_storage_class[:replicas] > cluster_config.worker_hosts.count
  end

  def default_replica_count
    cluster_config.worker_hosts.count < 3 ? cluster_config.worker_hosts.count : 3
  end
end
