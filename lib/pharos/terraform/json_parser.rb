require 'json'

module Pharos
  module Terraform
    class JsonParser

      # @param json [String]
      def initialize(json)
        @data = JSON.parse(json)
      end

      # @return [Array<Hash>]
      def hosts
        hosts = []
        values = @data.dig('pharos', 'value')
        values.each do |_, arr|
          bundle = arr[0]
          bundle['address'].each_with_index do |h, i|
            hosts << parse_host(bundle, h, i)
          end
        end
        hosts
      end

      # @param bundle [Hash]
      # @param host [Hash]
      # @param i [Integer]
      # @return [Hash]
      def parse_host(bundle, host, i)
        host = {
          address: host,
          private_address: bundle['private_address'][i],
          role: bundle['role'] || 'worker'
        }
        host[:labels] = bundle['label'][0] if bundle['label']
        host[:user] = bundle['user'] if bundle['user']
        host[:ssh_key_path] = bundle['ssh_key_path'] if bundle['ssh_key_path']

        host
      end
    end
  end
end