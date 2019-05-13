# frozen_string_literal: true

require 'pharos/phases/mixins/cluster_version'

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      include Pharos::Phases::Mixins::ClusterVersion

      title "Migrate master"

      def call
        if existing_version == pharos_version
          logger.info 'Nothing to migrate.'
          return
        end

        if existing_version > build_version('1.0.0') && existing_version < build_version('2.3.0-alpha.1')
          logger.info 'Migrating cluster info ...'
          migrate_cluster_info
        end

        if existing_version < build_version('2.4.0-alpha.0')
          logger.info 'Triggering etcd certificate refresh ...'
          cluster_context['recreate-etcd-certs'] = true
        end
      end

      def migrate_cluster_info
        cm_client = kube_client.api('v1').resource('configmaps', namespace: 'kube-public')
        cluster_info = cm_client.get('cluster-info')
        cm_client.delete('cluster-info')

        new_cluster_info = K8s::Resource.new(
          kind: cluster_info.kind,
          apiVersion: cluster_info.apiVersion,
          metadata: {
            name: cluster_info.metadata.name,
            namespace: cluster_info.metadata.namespace
          },
          data: cluster_info.data.to_h
        )
        cm_client.create_resource(new_cluster_info)
      rescue K8s::Error::NotFound
        logger.info "The cluster-info configmap has gone, skipping the migration ..."
      end
    end
  end
end
