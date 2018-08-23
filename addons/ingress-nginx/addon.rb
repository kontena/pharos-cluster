# frozen_string_literal: true

Pharos.addon 'ingress-nginx' do
  version '0.17.1'
  license 'Apache License 2.0'

  config {
    attribute :configmap, Pharos::Types::Hash
    attribute :node_selector, Pharos::Types::Hash
    attribute :default_backend, Pharos::Types::Hash
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
      image: image_name,
      default_backend_replicas: default_backend_replicas
    )
  }

  def image_name
    return config.default_backend[:image] if config.default_backend&.dig(:image)

    if cpu_arch.name == 'amd64'
      'docker.io/kontena/pharos-default-backend:0.0.2'
    else
      "docker.io/kontena/pharos-default-backend-#{cpu_arch.name}:0.0.2"
    end
  end

  # ~One replica per 10 workers, min 2
  # @return [Integer]
  def default_backend_replicas
    r = (@cluster_config.worker_hosts.size / 10.to_f).ceil

    return 2 if r < 2
    r
  end
end
