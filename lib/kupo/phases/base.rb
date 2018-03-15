# frozen_string_literal: true

require_relative 'logging'

module Kupo::Phases
  class Base
    include Kupo::Phases::Logging

    REMOTE_OUTPUT_INDENT = (' ' * 4).freeze

    def self.register_component(component)
      @@components ||= Set.new
      @@components << component
    end

    def self.components
      @@components
    end

    def debug?
      ENV['DEBUG'].to_s == 'true'
    end

    def remote_output(_type, data)
      if debug?
        data.each_line { |line|
          print pastel.dim(REMOTE_OUTPUT_INDENT + line)
        }
      end
    end

    def pastel
      @pastel ||= Pastel.new
    end

    def ssh_exec_file(ssh, file)
      tmp_file = File.join('/tmp', SecureRandom.hex(16))
      ssh.upload(file, tmp_file)
      code = ssh.exec("sudo chmod +x #{tmp_file} && sudo #{tmp_file}") do |type, data|
        remote_output(type, data)
      end
      ssh.exec("sudo rm #{tmp_file}")
      if code != 0
        raise Kupo::ScriptExecError, "Script execution failed: #{file}"
      end
    end
  end
end
