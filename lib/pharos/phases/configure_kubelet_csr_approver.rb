# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureKubeletCsrApprover < Pharos::Phase
      title "Configure kubelet csr auto-approver"

      RUBBER_STAMP_VERSION = '0.1.0'

      register_component(
        name: 'kubelet-rubber-stamp', version: RUBBER_STAMP_VERSION, license: 'Apache License 2.0'
      )

      def call
        apply_stack(
          "kubelet_rubber_stamp",
          version: RUBBER_STAMP_VERSION,
          image_repository: @config.image_repository
        )
      end
    end
  end
end
