# frozen_string_literal: true

Pharos.addon 'rook-ceph' do
  version '0.8.1'
  license 'Apache License 2.0'

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
        name: 'rook-ceph',
        namespace: 'rook-ceph'
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
