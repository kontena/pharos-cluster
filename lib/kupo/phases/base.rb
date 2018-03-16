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

    def exec_script(script, vars = {})
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      parsed_file = Kupo::Erb.new(File.read(file)).render(vars)
      @ssh.exec_script!(parsed_file, debug_source: "scripts/#{script}")
    rescue SSH::ExecError => exc
      raise Kupo::ScriptExecError, "Failed to execute #{script}:\n#{exc.output}"
    end
  end
end
