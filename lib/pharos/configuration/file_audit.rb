# frozen_string_literal: true

module Pharos
  module Configuration
    class FileAudit < Pharos::Configuration::Struct
      attribute :path, Pharos::Types::String
      attribute :max_age, Pharos::Types::Integer
      attribute :max_backups, Pharos::Types::Integer
      attribute :max_size, Pharos::Types::Integer
    end
  end
end
