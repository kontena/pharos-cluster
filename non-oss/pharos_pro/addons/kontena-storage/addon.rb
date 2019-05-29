# frozen_string_literal: true

Pharos.addon 'kontena-storage' do
  version '0.9.3+kontena.1'
  ceph_version = '13.2.4-20190109'
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
          required(:path).filled(:str?)
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
    cluster = build_cluster_resource(ceph_version)
    if upgrade_from?('0.8')
      upgrade_from_08(cluster, ceph_version)
    else
      apply_resources(
        cluster: cluster.to_h.deep_transform_keys(&:to_s),
        rook_version: rook_version
      )
    end
  }

  reset_host { |host|
    data_dir = config.data_dir.strip
    host.transport.exec("sudo rm -rf #{data_dir}/*") unless data_dir.empty?
  }

  def set_defaults
    return if config&.pool&.replicated

    config[:pool] = {
      replicated: {
        size: 3
      }
    }
  end

  # @return [String]
  def rook_version
    self.class.version.split('+').first
  end

  # @param cluster [K8s::Resource]
  # @param ceph_version [String]
  def upgrade_from_08(cluster, ceph_version)
    storage_stack = kube_stack(
      cluster: cluster.to_h.deep_transform_keys(&:to_s),
      rook_version: rook_version
    )
    logger.info "Applying upgrade ..."
    storage_stack.apply(kube_client, prune: false)

    logger.info "Waiting for new operator ..."
    wait_mgr_upgrade(ceph_version)

    logger.info "Cleaning up old configurations ..."
    storage_stack.prune(kube_client, keep_resources: true)
    remove_old_mgr(ceph_version)
  end

  # Wait new ceph mgr replica set
  #
  # @param ceph_version [String]
  def wait_mgr_upgrade(ceph_version)
    rs_client = kube_client.api('extensions/v1beta1').resource('replicasets', namespace: 'kontena-storage')
    upgraded = false
    while !upgraded
      upgraded = rs_client.list(labelSelector: 'app=rook-ceph-mgr').any? { |rs|
        rs.spec.template.spec.containers.first.image.include?("ceph/ceph:v#{ceph_version}")
      }
      sleep 1
    end

    true
  end

  # Remove old ceph mgr replica sets
  #
  # @param ceph_version [String]
  def remove_old_mgr(ceph_version)
    rs_client = kube_client.api('extensions/v1beta1').resource('replicasets', namespace: 'kontena-storage')
    old_replicasets = rs_client.list(labelSelector: 'app=rook-ceph-mgr').reject do |rs|
      rs.spec.template.spec.containers.first.image.include?("ceph/ceph:v#{ceph_version}")
    end
    old_replicasets.each do |rs|
      rs_client.delete_resource(rs, propagationPolicy: 'Background')
    end
  end

  # @param version [String]
  # @return [Boolean]
  def upgrade_from?(version)
    operator = kube_client.api('apps/v1beta1')
                          .resource('deployments', namespace: 'kontena-storage-system')
                          .get('kontena-storage-operator')

    operator.spec.template.spec.containers.first.image.include?("rook-ceph:v#{version}")
  rescue K8s::Error::NotFound
    false
  end

  # @param ceph_version [String]
  # @return [K8s::Resource]
  def build_cluster_resource(ceph_version)
    K8s::Resource.new(
      apiVersion: 'ceph.rook.io/v1',
      kind: 'CephCluster',
      metadata: {
        name: 'kontena-storage',
        namespace: 'kontena-storage'
      },
      spec: {
        cephVersion: {
          image: "#{cluster_config.image_repository}/ceph:v#{ceph_version}"
        },
        mon: {
          count: 3
        },
        serviceAccount: 'kontena-storage-cluster',
        dataDirHostPath: config.data_dir,
        storage: {
          useAllNodes: config.storage&.use_all_nodes,
          useAllDevices: false,
          deviceFilter: config.storage&.device_filter,
          directories: config.storage&.directories,
          nodes: config.storage&.nodes&.map { |n| n.to_h.deep_transform_keys(&:camelback) } || []
        },
        placement: (config.placement || {}).to_h.deep_transform_keys(&:camelback),
        resources: (config.resources || {}).to_h.deep_transform_keys(&:camelback),
        dashboard: (config.dashboard || { enabled: false }).to_h
      }
    )
  end
end
