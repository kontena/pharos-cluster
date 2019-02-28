# frozen_string_literal: true

require 'json'

module Pharos
  module Terraform
    class JsonParser
      class ParserError < Pharos::Error; end

      # @param json [String]
      def initialize(json)
        @json = json
      end

      def data
        @data ||= JSON.parse(@json)
      rescue JSON::ParserError => ex
        raise ParserError, ex.message
      end

      # @return [Array<Hash>]
      def hosts
        hosts = []
        values = data.dig('pharos_hosts', 'value') || data.dig('pharos', 'value')
        values.each do |_, arr|
          bundle = arr[0]
          bundle['address'].each_with_index do |h, i|
            hosts << parse_host(bundle, h, i)
          end
        end
        hosts
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

      # @param bundle [Hash]
      # @param host [Hash]
      # @param index [Integer]
      # @return [Hash]
      def parse_host(bundle, host, index)
        host = {
          address: host,
          role: bundle['role'] || 'worker'
        }
        host[:private_address] = bundle['private_address'][index] if bundle['private_address']
        host[:private_interface] = bundle['private_interface'][index] if bundle['private_interface']
        host[:labels] = bundle['label'][0] if bundle['label']
        host[:taints] = bundle['taint'] if bundle['taint']
        host[:environment] = bundle['environment'] if bundle['environment']
        host[:user] = bundle['user'] if bundle['user']
        host[:ssh_key_path] = bundle['ssh_key_path'] if bundle['ssh_key_path']
        host[:bastion] = bundle['bastion'][0] if bundle['bastion']
        host[:ssh_proxy_command] = bundle['ssh_proxy_command'] if bundle['ssh_proxy_command']
        host[:container_runtime] = bundle['container_runtime'] if bundle['container_runtime']

        host
      end
    end
  end
end
