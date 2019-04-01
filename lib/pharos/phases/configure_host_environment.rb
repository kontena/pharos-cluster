# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureHostEnvironment < Pharos::Phase
      title "Configure host environment"

      def call
        logger.info { "Updating environment file ..." }
        host_configurer.update_env_file
      end
    end
  end
end
