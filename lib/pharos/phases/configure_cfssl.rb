# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureCfssl < Pharos::Phase
      title "Configure cfssl"

      register_component(
        Pharos::Phases::Component.new(
          name: 'cfssl', version: '1.2', license: 'MIT'
        )
      )

      def call
        info 'Installing cfssl ...'
        exec_script(
          'configure-cfssl.sh',
          ARCH: @host.cpu_arch.name
        )
      end
    end
  end
end
