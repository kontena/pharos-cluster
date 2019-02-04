# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureTelemetry < Pharos::Phase
      title "Configure telemetry"

      TOKEN_FILE = File.join(Dir.home, '.chpharosrc').freeze

      def call
        if @config.telemetry.enabled
          logger.info { "Configuring telemetry service ..." }
          apply_stack(
            'telemetry',
            version: Pharos::TELEMETRY_VERSION,
            image_repository: @config.image_repository,
            arch: @host.cpu_arch,
            customer_token: Base64.strict_encode64(customer_token)
          )
        else
          logger.info { "Disabling telemetry service ..." }
          delete_stack('telemetry')
        end
      end

      # @return [String]
      def customer_token
        return '' unless File.exist?(TOKEN_FILE)

        match = File.read(TOKEN_FILE).match(/^CHPHAROS_TOKEN="(.+)"$/)
        return '' unless match

        match[1]
      end
    end
  end
end
