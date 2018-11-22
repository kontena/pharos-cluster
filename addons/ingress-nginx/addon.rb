# frozen_string_literal: true

Pharos.addon 'ingress-nginx' do
  version '0.17.1'
  license 'Apache License 2.0'

  config {
    attribute :configmap, Pharos::Types::Hash.default(
      'worker-shutdown-timeout' => '3600s' # keep connection/workers alive for 1 hour
    )
    attribute :node_selector, Pharos::Types::Hash
    attribute :default_backend, Pharos::Types::Hash.default(
      'image' => 'registry.pharos.sh/kontenapharos/pharos-default-backend:0.0.3'
    )
    attribute :tolerations, Pharos::Types::Array.default([])
  }

  config_schema {
    optional(:configmap).filled(:hash?)
    optional(:node_selector).filled(:hash?)
    optional(:default_backend).schema {
      optional(:image).filled(:str?)
    }
    optional(:tolerations).each(:hash?)
  }

  install {
    apply_resources(
      configmap: config.configmap || {},
      node_selector: config.node_selector || {},
      default_backend_image: config.default_backend['image'],
      default_backend_replicas: default_backend_replicas
    )
  }

  # ~One replica per 10 workers, but not more than nodes
  # @return [Integer]
  def default_backend_replicas
    r = (worker_node_count / 10.to_f).ceil

    return 1 if worker_node_count <= 1 # covers also single node cluster case where master is un-tainted
    return 2 if r < 2 && worker_node_count > 1 # Always min 2 replicas if 2 or more nodes

    r
  end

  # Counts the worker nodes
  def worker_node_count
    @worker_node_count ||= kube_client.api('v1').resource('nodes').list(labelSelector: 'node-role.kubernetes.io/master!=').size
  end
end
