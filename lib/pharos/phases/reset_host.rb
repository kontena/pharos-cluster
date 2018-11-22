# frozen_string_literal: true

module Pharos
  module Phases
    class ResetHost < Pharos::Phase
      title "Reset hosts"

      def call
        logger.info { "Removing all traces of Kontena Pharos ..." }
        host_configurer.reset
        if @config.addons.dig('kontena-lens', 'enabled')
          data_dir = @config.addons.dig('kontena-lens', 'data_dir').strip
          @ssh.exec("sudo rm -rf #{data_dir}/*") unless data_dir.empty?
        end
      end
    end
  end
end
