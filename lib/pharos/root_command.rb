# frozen_string_literal: true

require_relative 'up_command'
require_relative 'reset_command'
require_relative 'version_command'
require_relative 'kubeconfig_command'
require_relative 'license_command'

module Pharos
  class RootCommand < Pharos::Command
    banner "#{File.basename($PROGRAM_NAME)} - Kontena Pharos cluster manager"

    subcommand ["build", "up"], "initialize/upgrade cluster", UpCommand
    subcommand "kubeconfig", "fetch admin kubeconfig file", KubeconfigCommand
    subcommand "reset", "reset cluster", ResetCommand
    subcommand "license", "license subcommands", LicenseCommand
    subcommand ["version"], "show version information", VersionCommand

    def self.run
      super
    rescue StandardError => exc
      warn exc.message
      warn exc.backtrace.join("\n")
    end
  end
end
