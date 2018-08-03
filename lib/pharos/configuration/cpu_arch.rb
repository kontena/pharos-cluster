# frozen_string_literal: true

module Pharos
  module Configuration
    class CpuArch < Pharos::Configuration::Struct
      SUPPORTED_IDS = %w(
        amd64 x86_64
        arm64 aarch64
      ).freeze

      attribute :id, Pharos::Types::Strict::String

      # @return [Boolean]
      def supported?
        SUPPORTED_IDS.include?(id)
      end

      def name
        case id
        when 'x86_64'
          'amd64'
        when 'aarch64'
          'arm64'
        else
          id
        end
      end
    end
  end
end
