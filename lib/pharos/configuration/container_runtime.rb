# frozen_string_literal: true

module Pharos
  module Configuration
    class ContainerRuntime < Pharos::Configuration::Struct
      attribute :insecure_registries, Pharos::Types::Array.default(proc { [] })
    end
  end
end
