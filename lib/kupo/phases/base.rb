# frozen_string_literal: true

require_relative 'logging'
require_relative '../phases'

module Kupo
  module Phases
    class Base
      include Kupo::Phases::Logging

      def self.register_component(component)
        Kupo::Phases.components << component
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        @ssh.exec_script!(script,
                          env: vars,
                          path: File.realpath(File.join(__dir__, '..', 'scripts', script)))
      end

      # @param path [String] path on host
      # @param script [String] name of file under ../scripts/
      def install_script(path, script)
        @ssh.install_file(path, File.realpath(File.join(__dir__, '..', 'scripts', script)),
          mode: 0o755,
        )
      end
    end
  end
end
