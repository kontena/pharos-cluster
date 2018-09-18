# frozen_string_literal: true

module Pharos
  module Phases
    class UpgradeCheck < Pharos::Phase
      title "Check for Pharos upgrade"

      VERSION_URL = ENV["PHAROS_UPGRADE_CHECK_URL"] || 'https://get.pharos.sh/versions/latest'

      def call
        logger.info 'Checking for a new version ...'
        check_version
      end

      def check_version
        if latest_version > current_version
          logger.warn "There's a new version available: #{latest_version}."
        else
          logger.info 'Already at the latest version'
        end
      rescue StandardError => ex
        logger.debug { "Upgrade check encountered an error: #{ex} : #{ex.message}" }
      end

      private

      def current_version
        @current_version ||= Gem::Version.new(Pharos::VERSION)
      end

      def latest_version
        return @latest_version if @latest_version

        version = Excon.get(
          VERSION_URL,
          headers: { 'User-Agent' => "pharos/#{Pharos::VERSION}" },
          query: @channel == :pre ? { pre: true } : {}
        ).body

        raise "Invalid version response format: #{version}" unless version.match?(/^\d+\.\d+\.\d+(\-\S+)?$/)

        @latest_version = Gem::Version.new(version)
      end
    end
  end
end
