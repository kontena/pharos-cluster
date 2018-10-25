# frozen_string_literal: true

require 'json'

module Pharos
  module Terraform
    class JsonParser
      class ParserError < Pharos::Error; end

      using Pharos::CoreExt::DeepTransformKeys

      HOST_DEFAULTS = { role: 'worker' }.freeze

      # @param json [String]
      def initialize(json)
        @json = json
      end

      def data
        @data ||= JSON.parse(@json)
      rescue JSON::ParserError => ex
        raise ParserError, ex.message
      end

      # @return [Hash]
      def addons
        addons = {}
        addons_hash = data.dig('pharos_addons', 'value') || {}
        addons_hash.each do |name, array|
          addons[name] = array.first
        end

        addons
      end

      # @return [String,NilClass]
      def api
        @api ||= data.dig('pharos_api', 'value')
      end

      def hosts
        host_bundles.map do |bundle|
          addresses = bundle_host_addresses(Array(bundle.delete('address')), Array(bundle.delete('private_address')))

          # Take out the hashes
          hashes = {
            labels: bundle.delete('label')&.first,
            taints: bundle.delete('taint')&.first,
            environment: bundle.delete('environment')&.first
          }.compact

          # Symbolize and merge over defaults and restore the hashes
          bundle = HOST_DEFAULTS.merge(bundle.deep_symbolize_keys).merge(hashes)

          # Glue the bundle into each address hash
          addresses.map { |address| address.merge(bundle) }
        end.inject(:+)
      end

      def host_bundles
        (data.dig('pharos_hosts', 'value') || data.dig('pharos', 'value')).values.map(&:first)
      end

      def bundle_host_addresses(public_addresses, private_addresses)
        unless public_addresses.empty? || private_addresses.empty?
          raise "address and private_address array size mismatch" unless public_addresses.size == private_addresses.size
        end

        if public_addresses.empty? || private_addresses.empty?
          (public_addresses + private_addresses).map { |address| { address: address } }
        else
          public_addresses.zip(private_addresses).map do |public_address, private_address|
            { address: public_address, private_address: private_address }
          end
        end
      end
    end
  end
end
