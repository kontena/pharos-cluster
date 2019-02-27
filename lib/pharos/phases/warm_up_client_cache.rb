# frozen_string_literal: true

module Pharos
  module Phases
    class WarmUpClientCache < Pharos::Phase
      title "Warm up client cache"

      def call
        logger.info "Warming up Kubernetes API client cache"
        kube_client.apis(prefetch_resources: true)
      end
    end
  end
end
