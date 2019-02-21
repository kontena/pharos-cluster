# frozen_string_literal: true

require 'time'
require 'ostruct'

module Pharos
  class LicenseKey
    attr_reader :token

    # @param token [String] Kontena Pharos license JWT
    def initialize(token, cluster_id: nil)
      @token = token
      @cluster_id = cluster_id
      validate
    end

    # @return [Array<String>] validation errors
    def errors
      @errors ||= []
    end

    # @return [Boolean] true when token is valid
    def valid?
      errors.empty?
    end

    # @return [OpenStruct] data struct with decoded license data
    def decode_token
      OpenStruct.new(
        JSON.load(Base64.decode64(token[/\.(.+?)\./, 1])).fetch('data').tap do |data|
          data['days_left'] = (Time.parse(data['valid_until']) - Time.now.utc).to_i / 86_400
        end
      )
    end

    # @return [Hash] license data
    def data
      return @data if @data

      validate
      @data
    end

    def to_h
      (data&.to_h || {}).transform_keys(&:to_s).tap do |hash|
        hash['errors'] = errors unless valid?
      end
    end

    # @return [Boolean] validation result
    def validate
      errors.clear

      @data = decode_token
      if @data.nil?
        errors << "Can't decode token"
        return false
      end

      errors << "License expired #{data.days_left} days ago" if data.days_left.negative?
      errors << "License status is #{data.status}" unless data.status == 'valid'
      errors << "License is not for this cluster" if @cluster_id && @cluster_id != data.cluster_id

      errors.empty?
    end
  end
end
