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

    # @return [Array<String>]
    def errors
      data['errors']
    end

    # @return [Boolean] true when token is valid
    def valid?
      errors.empty?
    end

    # @return [Hash] license data
    def data
      @data ||= decode_payload
    end
    alias to_h data

    private

    def validate
      errors = []
      errors << "License has expired" if Time.parse(data['valid_until']) < Time.now.utc
      errors << "License status is #{data['status']}" unless data['status'] == 'valid'
      errors << "License is not for this cluster" if @cluster_id && @cluster_id != data['cluster_id']
      data['errors'] = errors unless errors.empty?
      data.freeze

      errors.empty?
    end

    def decode_payload
      JSON.parse(Base64.decode64(payload)).fetch('data')
    rescue StandardError => ex
      errors << "Can't decode token payload (#{ex.class.name} : #{ex.message})"
      {}
    end

    def payload
      token.split('.', 3)[1]
    end
  end
end
