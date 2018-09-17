# frozen_string_literal: true

require 'open-uri'

module Pharos
  class UpgradeChecker
    include Pharos::Logging

    VERSION_URL = ENV["PHAROS_UPGRADE_CHECK_URL"] || 'https://get.pharos.sh/versions/latest'

    def self.run
      new(ENV['PHAROS_CHANNEL']).run
    end

    def initialize(channel = nil)
      @uri = URI(VERSION_URL)
      @uri.query = 'pre=true' if channel && channel.to_s == 'pre'
    end

    def run
      logger.debug 'Checking for an upgrade ..'
      latest_version = @uri.open('User-Agent' => "pharos/#{Pharos::VERSION}").read.chomp
      raise "Invalid version string format: #{latest_version}" unless latest_version.match?(/^\d+\.\d+\.\d+(\-\S+)?$/)
      if Gem::Version.new(latest_version) > Gem::Version.new(Pharos::VERSION)
        warn Pastel.new(enabled: $stderr.tty?).magenta("There's a new version available: #{latest_version}")
      else
        logger.debug { 'Already at the latest version' }
      end
    rescue StandardError => ex
      logger.debug { "Upgrade check encountered an error: #{ex} : #{ex.message}" }
    end
  end
end
