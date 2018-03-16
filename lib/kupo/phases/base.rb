require_relative 'logging'

module Kupo::Phases
  class Base
    include Kupo::Phases::Logging

    def self.register_component(component)
      @@components ||= Set.new
      @@components << component
    end

    def self.components
      @@components
    end

    # @param script [String] name of file under ../scripts/
    def exec_script(script, vars = {})
      @ssh.exec_script!(script,
        env: vars,
        path: File.realpath(File.join(__dir__, '..', 'scripts', script)),
      )
    rescue SSH::ExecError => exc
      raise Kupo::ScriptExecError, "Failed to execute #{script}:\n#{exc.output}"
    end
  end
end
