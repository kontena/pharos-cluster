# frozen_string_literal: true

require_relative 'up_command'
require_relative 'reset_command'
require_relative 'version_command'
require_relative 'kubeconfig_command'

module Pharos
  class RootCommand < Pharos::Command
    banner "pharos-cluster - Kontena Pharos cluster manager"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand
    subcommand "kubeconfig", "Download kubernetes configuration files", KubeconfigCommand
    subcommand "reset", "Reset cluster", ResetCommand
    subcommand "version", "Show version information", VersionCommand

    def self.run
      super
    rescue StandardError => exc
      warn exc.message
      warn exc.backtrace.join("\n")
    end
  end
end
