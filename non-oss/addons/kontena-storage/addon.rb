# frozen_string_literal: true

Pharos.addon 'kontena-storage' do
  version '0.8.0'
  license 'Kontena License'

  config_schema {
    required(:data_dir).filled(:str?)
    required(:storage).schema do
      required(:use_all_nodes).filled(:bool?)
      optional(:device_filter).filled(:str?)
      optional(:nodes).each do
        schema do
          required(:name).filled(:str?)
          optional(:directories).each do
            schema do
              required(:name).filled(:str?)
            end
          end
          optional(:device_filter).filled(:str?)
          optional(:devices).each do
            schema do
              required(:name).filled(:str?)
            end
          end
          optional(:config).schema
          optional(:resources).schema do
            optional(:limits).schema do
              required(:cpu).filled(:str?)
              required(:memory).filled(:str?)
            end
            optional(:requests).schema do
              required(:cpu).filled(:str?)
              required(:memory).filled(:str?)
            end
          end
        end
      end
      optional(:directories).each do
        schema do
          required(:name).filled(:str?)
        end
      end
    end
    optional(:placement).schema do
      optional(:all).schema
      optional(:mgr).schema
      optional(:mon).schema
      optional(:osd).schema
    end
    optional(:resources).schema do
      optional(:mgr).schema do
        optional(:limits).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
        optional(:requests).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
      end
      optional(:mon).schema do
        optional(:limits).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
        optional(:requests).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
      end
      optional(:osd).schema do
        optional(:limits).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
        optional(:requests).schema do
          required(:cpu).filled(:str?)
          required(:memory).filled(:str?)
        end
      end
    end
    optional(:dashboard).schema do
      required(:enabled).filled(:bool?)
    end
    optional(:pool).schema do
      required(:replicated).schema do
        required(:size).filled(:int?)
      end
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
        serviceAccount: 'kontena-storage-cluster',
        dataDirHostPath: config.data_dir,
        storage: {
          useAllNodes: config.storage&.use_all_nodes || true,
          useAllDevices: false,
          deviceFilter: config.storage&.device_filter,
          nodes: config.storage&.nodes&.map { |n| n.to_h.to_camelback_keys }
        },
        placement: (config.placement || {}).to_h.to_camelback_keys,
        resources: (config.resources || {}).to_h.to_camelback_keys,
        dashboard: config.dashboard || { enabled: false }
      }
    )
    apply_resources(cluster: stringify_hash(cluster.to_h))
  }

  def stringify_hash(hash)
    JSON.parse(JSON.dump(hash))
  end
end
