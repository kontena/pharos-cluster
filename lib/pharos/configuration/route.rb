# frozen_string_literal: true

require 'ipaddr'

module Pharos
  module Configuration
    class Route < Pharos::Configuration::Struct
      ROUTE_REGEXP = %r(^((?<type>\S+)\s+)?(?<prefix>default|[0-9./]+)(\s+via (?<via>\S+))?(\s+dev (?<dev>\S+))?(\s+proto (?<proto>\S+))?(\s+(?<options>.+))?$)

      # @param line [String]
      # @return [Pharos::Configuration::Route]
      # @raise [RuntimeError] invalid route
      def self.parse(line)
        fail "Unmatched ip route: #{line.inspect}" unless match = ROUTE_REGEXP.match(line.strip)

        captures = Hash[match.named_captures.map{ |k, v| [k.to_sym, v] }.reject{ |_k, v| v.nil? }]

        new(raw: line.strip, **captures)
      end

      attribute :raw, Pharos::Types::Strict::String
      attribute :type, Pharos::Types::Strict::String.optional
      attribute :prefix, Pharos::Types::Strict::String
      attribute :via, Pharos::Types::Strict::String.optional
      attribute :dev, Pharos::Types::Strict::String.optional
      attribute :proto, Pharos::Types::Strict::String.optional
      attribute :options, Pharos::Types::Strict::String.optional

      def to_s
        @raw
      end

      # @return [Boolean]
      def overlaps?(cidr)
        # special-case the default route and ignore it
        return nil if prefix == 'default'

        route_prefix = IPAddr.new(prefix)
        cidr = IPAddr.new(cidr)

        route_prefix.include?(cidr) || cidr.include?(route_prefix)
      end
    end
  end
end
