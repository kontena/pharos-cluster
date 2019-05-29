# frozen_string_literal: true

require 'pharos/phases/mixins/cluster_version'

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      include Pharos::Phases::Mixins::ClusterVersion

      title "Migrate master"

      def call
        # rubocop:disable Style/GuardClause
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
          recreate_etcd_certs
          logger.info 'Fixing tolerations ...'
          fix_lens_redis_tolerations
        end
        # rubocop:enable Style/GuardClause
      end

      def fix_lens_redis_tolerations
        resource_client = kube_client.api('extensions/v1beta1').resource('deployments', namespace: 'kontena-lens')
        resource_client.merge_patch(
          'redis',
          {
            spec: {
              template: {
                spec: {
                  tolerations: [
                    {
                      effect: 'NoSchedule',
                      operator: 'Exists',
                      key: 'node-role.kubernetes.io/master'
                    }
                  ]
                }
              }
            }
          }
        )
        pod_client = kube_client.api('v1').resource('pods', namespace: 'kontena-lens')
        pod_client.delete_collection(labelSelector: 'app=dashboard')
      rescue K8s::Error::NotFound
        logger.debug "kontena-lens redis not found"
      end

      def recreate_etcd_certs
        cluster_context['recreate-etcd-certs'] = true
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
