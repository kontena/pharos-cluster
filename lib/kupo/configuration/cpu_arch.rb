# frozen_string_literal: true

module Kupo::Configuration
  class CpuArch < Dry::Struct
    constructor_type :schema

    SUPPORTED_IDS = %w[
      amd64 x86_64
      arm64 aarch64
    ].freeze

    attribute :id, Kupo::Types::Strict::String

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
