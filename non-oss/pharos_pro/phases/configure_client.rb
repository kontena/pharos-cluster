# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClient < Pharos::Phase
      def call
        return if @optional && !kubeconfig?

        check_icebox

        cluster_context['kubeconfig'] = kubeconfig

        client_prefetch unless @optional
      end

      def check_icebox
        return unless transport.exec?("kubectl get pods --namespace=kube-system -o custom-columns=name:.metadata.name | grep -q pharos-license-enforcer")

        logger.debug "Check if license-enforcer has iceboxed the cluster"

        master_count = transport.exec!('kubectl get nodes -l node-role.kubernetes.io/master= --no-headers | wc -l').to_i
        scheduler_pods_count = transport.exec!('kubectl get pods --namespace=kube-system -l component=kube-scheduler --no-headers | wc -l').to_i
        controller_manager_pods_count = transport.exec!('kubectl get pods --namespace=kube-system -l component=kube-controller-manager --no-headers | wc -l').to_i

        unless master_count == scheduler_pods_count && master_count == controller_manager_pods_count
          raise "The cluster is in icebox state because the license has expired"
        end

        logger.debug "No icebox"
      end
    end
  end
end
