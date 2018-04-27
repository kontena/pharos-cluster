# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCfssl < Pharos::Phase
      title "Configure cfssl"

      register_component(
        name: 'cfssl', version: '1.2', license: 'MIT',
        enabled: Proc.new { |c| !c.etcd&.endpoints }
      )

      def call
        logger.info { 'Installing cfssl ...' }
        exec_script(
          'configure-cfssl.sh',
          ARCH: @host.cpu_arch.name
        )
      end
    end
  end
end
