# frozen_string_literal: true

module Pharos
  module Configuration
    class ResolvConf < Pharos::Configuration::Struct
      attribute :nameserver_localhost, Pharos::Types::Strict::Bool
      attribute :systemd_resolved_stub, Pharos::Types::Strict::Bool
    end
  end
end
