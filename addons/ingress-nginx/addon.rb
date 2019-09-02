# frozen_string_literal: true

Pharos.addon 'ingress-nginx' do
  version '0.25.1'
  license 'Apache License 2.0'

  default_values(
    kind: 'DaemonSet',
    deployment: {
      replicas: 2
    },
    configmap: {
      'worker-shutdown-timeout' => '3600s' # keep connection/workers alive for 1 hour
    },
    default_backend: {
      'image' => 'registry.pharos.sh/kontenapharos/pharos-default-backend:0.0.3'
    },
    tolerations: [],
    extra_args: []
  )

  config_schema do
    optional(:kind).filled(included_in?: ['DaemonSet', 'Deployment'])
    optional(:deployment).schema do
      required(:replicas).filled(:int?)
    end
    optional(:service).schema do
      required(:external_traffic_policy).filled(included_in?: ['Cluster', 'Local'])
    end
    optional(:replicas).filled(:int?)
    optional(:configmap).filled(:hash?)
    optional(:node_selector).filled(:hash?)
    optional(:default_backend).schema {
      required(:image).filled(:str?)
    }
    optional(:tolerations).each(:hash?)
    optional(:extra_args).each(:str?)
  end

  install {
    apply_resources(
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
