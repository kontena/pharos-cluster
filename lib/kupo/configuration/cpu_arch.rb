module Kupo::Configuration
  class CpuArch < Dry::Struct
    constructor_type :schema

    SUPPORTED_IDS = [
      'amd64', 'x86_64',
      'aarch64', 'arm64'
    ].freeze

    attribute :id, Kupo::Types::Strict::String

    # @return [Boolean]
    def supported?
      SUPPORTED_IDS.include?(self.id)
    end

    def name
      case self.id
      when 'x86_64'
        'amd64'
      when 'aarch64'
        'arm64'
      else
        self.id
      end
    end
  end
end