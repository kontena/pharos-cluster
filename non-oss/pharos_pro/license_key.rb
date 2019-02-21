# frozen_string_literal: true

require 'time'
require 'base64'
require 'json'

module Pharos
  class LicenseKey
    attr_reader :token

    # @param token [String] Kontena Pharos license JWT
    def initialize(token, cluster_id: nil)
      @token = token
      @cluster_id = cluster_id

      validate
      freeze
    end

    # @return [Array<String>] validation errors
    def errors
      @errors ||= []
    end

    # @return [Boolean] true when token is valid
    def valid?
      errors.empty?
    end

    # @return [Hash] decoded payload data
    def decode_payload
      JSON.parse(Base64.decode64(payload))
    rescue StandardError => ex
      errors << "Can't decode token payload (#{ex.class.name} : #{ex.message})"
      {}
    end

    # @return [Hash] license data
    def data
      @data ||= decode_payload['data']
    end

    # @return [Hash]
    def to_h
      (data&.to_h || {}).tap do |hash|
        hash['errors'] = errors unless valid?
      end
    end

    # @return [Boolean] validation result
    def validate
      return false if data.nil?

      errors << "License has expired" if Time.parse(data['valid_until']) < Time.now.utc
      errors << "License status is #{data['status']}" unless data['status'] == 'valid'
      errors << "License is not for this cluster" if @cluster_id && @cluster_id != data['cluster_id']

      errors.empty?
    end

    def payload
      token.split('.', 3)[1]
    end
  end
end
