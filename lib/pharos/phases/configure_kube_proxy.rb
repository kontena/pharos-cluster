# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureKubeProxy < Pharos::Phase
      title "Configure kube-proxy"

      def call
        logger.info { 'Configuring kube-proxy daemonset ...' }
        spec = {
          template: {
            spec: {
              containers: [
                {
                  name: "kube-proxy",
                  image: "#{@config.image_repository}/kube-proxy:v#{KUBE_VERSION}"
                }
              ],
              nodeSelector: nil
            }
          }
        }
        resource_client.merge_patch(
          'kube-proxy',
          spec: spec
        )
      end

      # @return [K8s::ResourceClient]
      def resource_client
        kube_client.api('extensions/v1beta1').resource('daemonsets', namespace: 'kube-system')
      end
    end
  end
end
