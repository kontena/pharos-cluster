# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCfssl < Pharos::Phase
      title "Configure cfssl"

      register_component 'cfssl', version: '1.2.0+git20160825.89.7fb22c8-3', license: 'MIT'

      def call
        logger.info { 'Installing cfssl ...' }
        exec_script(
          'configure-cfssl.sh',
          ARCH: @host.cpu_arch.name,
          VERSION: components.cfssl.version
        )
      end
    end
  end
end
