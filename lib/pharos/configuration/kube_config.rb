# frozen_string_literal: true

module Pharos
  module Configuration
    class KubeConfig < Pharos::Configuration::Struct
      attribute :path, Pharos::Types::String.optional
      attribute :user, Pharos::Types::String.optional
      attribute :context, Pharos::Types::String.optional
    end
  end
end

