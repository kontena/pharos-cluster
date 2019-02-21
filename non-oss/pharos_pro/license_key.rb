# frozen_string_literal: true

require 'time'
require 'jwt'
require 'ostruct'

module Pharos
  class LicenseKey
    def self.jwt_public_key
      @jwt_public_key ||= OpenSSL::PKey::RSA.new(<<~EOS)
        -----BEGIN PUBLIC KEY-----
        MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwgO55tqduo+jKRrvnOOJ
        KKvkOdaYvy4uW+9f5AkqZxOPRTb+AMiSg/bgGvZUc4YM6UoUmvHmq2TigRRWk/9Z
        bjulmJtbmypbLPf1D/ZIIHQkert63hR9ow/2SCTIEydyOGWLvVZPNd+LrAQT6Vpl
        2i/NSCd8GpkLTtxh7Qq7iVg2S4vERt7ueEyFkd7B/bpp3aOI+WWSolnPq1Av6fep
        9/MiKPN6tFpbjpRrEdGH84/G12hBB2PBmFxgqaZB0Q/kdxlqDmxOWDlXgugS34ty
        TJTyiregF4J8rCqVwKcV7qPrZBeuXQnZhFsGPjBuFFVAbR8ydC5n7WvPkYkcGFPF
        pQIDAQAB
        -----END PUBLIC KEY-----
      EOS
    end

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

    # @param verify [Boolean] will decode the token without verifying signature or expiration when false
    # @return [OpenStruct] data struct with decoded license data
    # @raise [JWT::DecodeError,JWT::VerificationError,JWT::ExpiredSignature]
    def decode(verify: true)
      OpenStruct.new(
        JWT.decode(token, self.class.jwt_public_key, verify, { algorithm: 'RS256' })&.first&.fetch('data', nil)&.tap do |data|
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

      verify = true
      begin
        @data = decode(verify: verify)
      rescue JWT::VerificationError, Jwt::ExpiredSignature => ex
        raise unless verify

        errors << "Verification failed (#{ex.class.name} : #{ex.message})"
        verify = false
        retry
      rescue StandardError => ex
        errors << "Decoding failed (#{ex.class.name} : #{ex.message})"
        @data = nil
        return false
      end

      errors << "License expired #{data.days_left} days ago" if data.days_left.negative?
      errors << "License status is #{data.status}" unless data.status == 'valid'
      errors << "License is not for this cluster" if @cluster_id && @cluster_id != data.cluster_id

      errors.empty?
    end
  end
end

