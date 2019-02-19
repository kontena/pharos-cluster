# frozen_string_literal: true

require_relative 'up_command'
require_relative 'reset_command'
require_relative 'version_command'
require_relative 'kubeconfig_command'
require_relative 'exec_command'

module Pharos
  class RootCommand < Pharos::Command
    banner "#{File.basename($PROGRAM_NAME)} - Kontena Pharos cluster manager"

    subcommand "up", "initialize/upgrade cluster", UpCommand
    subcommand "kubeconfig", "fetch admin kubeconfig file", KubeconfigCommand
    subcommand "reset", "reset cluster", ResetCommand
    subcommand %w(exec ssh), "run a command or an interactive session on a host", ExecCommand
    subcommand "version", "show version information", VersionCommand
  end
end
