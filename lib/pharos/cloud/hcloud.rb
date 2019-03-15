# frozen_string_literal: true

require_relative "provider"

module Pharos
  module Cloud
    class HCloud < Provider

      register_as :hcloud

      # @return [Hash]
      def feature_gates
        {
          'CSINodeInfo' => true,
          'CSIDriverRegistry' => true
        }
      end

      def csi?
        true
      end
    end
  end
end
