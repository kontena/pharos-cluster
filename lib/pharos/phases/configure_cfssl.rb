# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCfssl < Pharos::Phase
      title "Configure cfssl"

      def call
        logger.info { 'Installing cfssl ...' }
        @host.configurer(ssh).configure_cfssl
      end
    end
  end
end
