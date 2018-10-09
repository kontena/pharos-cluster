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

    "docker.io/kontena/pharos-default-backend-#{cpu_arch.name}:0.0.3"
  end

  # ~One replica per 10 workers, min 2
  # @return [Integer]
  def default_backend_replicas
    r = (worker_node_count / 10.to_f).ceil

    return 1 if worker_node_count <= 1 # covers also single node cluster case where master is un-tainted
    return 2 if r < 2 && worker_node_count > 1

    r
  end

  # Counts the worker nodes
  def worker_node_count
    @worker_node_count ||= kube_client.api('v1').resource('nodes').list(labelSelector: 'node-role.kubernetes.io/master!=').size
  end
end
