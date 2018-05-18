name 'openebs'
version '0.5.3'
license 'Apache License 2.0'

DEFAULT_CLASS_OPTS = {
  default_class: false,
  capacity: '5G'
}.freeze

DEFAULT_STORAGE_PATH = '/var/openebs'

DEFAULT_POOL_OPTS = {
  path: DEFAULT_STORAGE_PATH
}.freeze

struct {
  attribute :default_storage_class, Pharos::Types::Hash.default(DEFAULT_CLASS_OPTS)
  attribute :default_storage_pool, Pharos::Types::Hash.default(DEFAULT_POOL_OPTS)
}

schema {
  optional(:default_storage_class).schema do
    optional(:default_class).filled(:bool?)
    optional(:capacity).filled(:str?)
    optional(:replicas).filled(:int?)
  end

  optional(:default_storage_pool).schema do
    optional(:path).filled(:str?)
  end
}

def validate
  super
  raise Pharos::InvalidAddonError, "Cannot set more replicas than workers" if config.default_storage_class[:replicas] && config.default_storage_class[:replicas] > cluster_config.worker_hosts.count
end

def default_replica_count
  cluster_config.worker_hosts.count < 3 ? cluster_config.worker_hosts.count : 3
end

def install
  apply_stack(
    default_replicas: config.default_storage_class[:replicas] || default_replica_count,
    default_capacity: config.default_storage_class[:capacity] || '5G',
    is_default_class: config.default_storage_class[:default_class] == true,
    default_storage_pool_path: config.default_storage_pool[:path]
  )
end
