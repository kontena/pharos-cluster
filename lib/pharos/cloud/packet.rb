# frozen_string_literal: true

require_relative "provider"

module Pharos
  module Cloud
    class Packet < Provider

      register_as :packet

      def csi?
        false
      end
    end
  end
end
