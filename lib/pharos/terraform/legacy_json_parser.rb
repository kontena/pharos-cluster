# frozen_string_literal: true

require 'json'
require_relative 'json_parser'

module Pharos
  module Terraform
    class LegacyJsonParser
      # @param json [String]
      # @param path [String]
      def initialize(json, path)
        @json = json
        @path = path
      end

      def data
        @data ||= JSON.parse(@json)
      rescue JSON::ParserError => ex
        raise ParserError, ex.message + "in '#{path}'"
      end

      # @return [Array<Hash>]
      def hosts
        values = data.dig('pharos_hosts', 'value') || data.dig('pharos', 'value')
        hosts = []
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
        values = data.dig('pharos_addons', 'value') || {}
        values.each do |name, array|
          addons[name] = array.first
        end

        addons
      end

      # @return [String,NilClass]
      def api
        @api ||= data.dig('pharos_api', 'value')
      end

      # @return [String,NilClass]
      def cluster_name
        @cluster_name ||= data.dig('pharos_cluster', 'value', 'name')
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
        host[:environment] = bundle['environment'][0] if bundle['environment']
        host[:user] = bundle['user'] if bundle['user']
        host[:ssh_port] = bundle['ssh_port'] if bundle['ssh_port']
        host[:ssh_key_path] = bundle['ssh_key_path'] if bundle['ssh_key_path']
        host[:bastion] = bundle['bastion'][0] if bundle['bastion']
        host[:ssh_proxy_command] = bundle['ssh_proxy_command'] if bundle['ssh_proxy_command']
        host[:container_runtime] = bundle['container_runtime'] if bundle['container_runtime']

        host
      end
    end
  end
end
