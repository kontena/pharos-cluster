# frozen_string_literal: true

module Kupo
  module Configuration
    class SshOptions < Dry::Struct
      constructor_type :schema

      attribute :bind_address, Kupo::Types::Strict::String.optional
      attribute :compression, Kupo::Types::Strict::Bool.default(true)
      attribute :keepalive, Kupo::Types::Strict::Bool.default(false)
      attribute :keepalive_interval, Kupo::Types::Strict::Int.default(300)
      attribute :verbose, Kupo::Types::Strict::String.default('fatal')
      attribute :port, Kupo::Types::Strict::Int.default(22)
      attribute :host_key_alias, Kupo::Types::Strict::String.optional
      attribute :global_known_hosts_file, Kupo::Types::Strict::String.optional
      attribute :user_known_hosts_file, Kupo::Types::Strict::String.optional

      def to_h
        super.merge(verbose: verbose.to_sym)
      end
    end
  end
end
