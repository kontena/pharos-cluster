# frozen_string_literal: true

require 'json'

module Pharos
  module Terraform
    class ParserError < Pharos::Error; end

    class JsonParser
      # @param json [String]
      def initialize(json)
        @json = json
      end

      def data
        @data ||= JSON.parse(@json)
      rescue JSON::ParserError => ex
        raise ParserError, ex.message
      end

      def valid?
        data.dig('pharos_cluster', 'type').is_a?(Array)
      end

      # @return [Hash]
      def cluster
        data.dig('pharos_cluster', 'value')
      end
    end
  end
end
