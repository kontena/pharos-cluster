# frozen_string_literal: true

require_relative "provider"

module Pharos
  module Cloud
    class PharosCloud < Provider
      register_as :pharos

      def csi?
        false
      end
    end
  end
end
