# frozen_string_literal: true

Pharos.addon 'ingress-nginx' do
  version '0.17.1'
  license 'Apache License 2.0'

  config {
    attribute :configmap, Pharos::Types::Hash
    attribute :node_selector, Pharos::Types::Hash
    attribute :default_backend, Pharos::Types::Hash.default(
      'image' => 'registry.pharos.sh/kontenapharos/pharos-default-backend:0.0.3'
    )
  }

  config_schema {
    optional(:configmap).filled(:hash?)
    optional(:node_selector).filled(:hash?)
    optional(:default_backend).schema {
      optional(:image).filled(:str?)
    }
  }

  install {
    apply_resources(
      configmap: config.configmap || {},
      node_selector: config.node_selector || {},
      default_backend_replicas: default_backend_replicas
    )
  }

  # ~One replica per 10 workers, min 2
  # @return [Integer]
  def default_backend_replicas
    r = (@cluster_config.worker_hosts.size / 10.to_f).ceil

    return 2 if r < 2
    r
  end
end
