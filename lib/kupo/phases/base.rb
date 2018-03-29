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

      def parse_resource_file(path, vars = {})
        path = File.realpath(File.join(__dir__, '..', 'resources', path))
        yaml = File.read(path)
        Kupo::Erb.new(yaml).render(vars)
      end
    end
  end
end
