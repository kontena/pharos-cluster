# frozen_string_literal: true

Pharos.addon 'kontena-storage' do
  using Pharos::CoreExt::DeepTransformKeys
  version '0.8.3+kontena.1'
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
      optional(:all).filled(:hash?)
      optional(:mgr).filled(:hash?)
      optional(:mon).filled(:hash?)
      optional(:osd).filled(:hash?)
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
    optional(:filesystem).schema do
      required(:enabled).filled(:bool?)
      optional(:pool).schema do
        required(:replicated).schema do
          required(:size).filled(:int?)
        end
      end
    end
    optional(:pool).schema do
      required(:replicated).schema do
        required(:size).filled(:int?)
      end
    end
  }

  install {
    set_defaults
    cluster = build_cluster_resource
    apply_resources(
      cluster: cluster.to_h.deep_transform_keys(&:to_s),
      rook_version: self.class.version.split('+').first
    )
  }

  reset_host { |host|
    data_dir = config.data_dir.strip
    host.ssh.exec("sudo rm -rf #{data_dir}/*") unless data_dir.empty?
  }

  def set_defaults
    return if config&.pool&.replicated

    config[:pool] = {
      replicated: {
        size: 3
      }
    }
  end

  # @return [K8s::Resource]
  def build_cluster_resource
    K8s::Resource.new(
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
          useAllNodes: config.storage&.use_all_nodes,
          useAllDevices: false,
          deviceFilter: config.storage&.device_filter,
          nodes: config.storage&.nodes&.map { |n| n.to_h.deep_transform_keys(&:camelback) }
        },
        placement: (config.placement || {}).to_h.deep_transform_keys(&:camelback),
        resources: (config.resources || {}).to_h.deep_transform_keys(&:camelback),
        dashboard: (config.dashboard || { enabled: false }).to_h
      }
    )
  end
end
