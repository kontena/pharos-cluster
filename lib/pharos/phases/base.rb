# frozen_string_literal: true

require_relative 'logging'
require_relative '../phases'

module Pharos
  module Phases
    class Base
      include Pharos::Phases::Logging

      def self.register_component(component)
        Pharos::Phases.components << component
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        @ssh.exec_script!(script,
                          env: vars,
                          path: File.realpath(File.join(__dir__, '..', 'scripts', script)))
      end

      def parse_resource_file(path, vars = {})
        path = File.realpath(File.join(__dir__, '..', 'resources', path))
        Pharos::YamlFile.new(path).load(vars)
      end
    end
  end
end
