# frozen_string_literal: true

module Pharos
  module Phases
    module Mixins
      module PSP
        def apply_psp_stack
          apply_stack(
            'psp',
            default_psp: @config.pod_security_policy.default_policy
          )
        end
      end
    end
  end
end