# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigurePriorityClasses < Pharos::Phase
      title "Configure priority classes"

      def call
        apply_stack('priority_classes')
      end
    end
  end
end
