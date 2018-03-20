# frozen_string_literal: true

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

    def ssh_exec_file(ssh, file)
      tmp_file = File.join('/tmp', SecureRandom.hex(16))
      ssh.upload(file, tmp_file)
      ssh.exec!("sudo chmod +x #{tmp_file} && sudo #{tmp_file}")
    ensure
      ssh.exec("sudo rm #{tmp_file}") if tmp_file
    end

    def exec_script(script, vars = {})
      file = File.realpath(File.join(__dir__, '..', 'scripts', script))
      parsed_file = Kupo::Erb.new(File.read(file)).render(vars)
      ssh_exec_file(@ssh, StringIO.new(parsed_file))
    rescue Kupo::ScriptExecError
      raise Kupo::ScriptExecError, "Failed to execute #{script}"
    end
  end
end
