# frozen_string_literal: true

module Pharos
  module Phases
    class WarmUpClientCache < Pharos::Phase
      title "Warm up Kubernetes API client cache"

      def call
        kube_client.apis(prefetch_resources: true)
      end
    end
  end
end
