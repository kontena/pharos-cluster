# frozen_string_literal: true

Pharos.addon 'kontena-storage' do
  version '0.8.0'
  license 'Kontena License'

  config_schema {
    required(:dataDirHostPath).filled(:str?)
    required(:storage).schema
    optional(:placement).schema
    optional(:resources).schema
    optional(:dashboard).schema do
      required(:enabled).filled(:bool?)
    end
  }

  install {
    cluster = K8s::Resource.new(
      apiVersion: 'ceph.rook.io/v1beta1',
      kind: 'Cluster',
      metadata: {
        name: 'kontena-storage',
        namespace: 'kontena-storage'
      },
      spec: {
        dataDirHostPath: config.dataDirHostPath,
        storage: config.storage,
        placement: config.placement || {},
        resources: config.resources || {},
        dashboard: config.dashboard || { enabled: false }
      }
    )
    apply_resources(cluster: stringify_hash(cluster.to_h))
  }

  def stringify_hash(hash)
    JSON.parse(JSON.dump(hash))
  end
end
