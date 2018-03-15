# frozen_string_literal: true

require_relative 'up_command'
require_relative 'version_command'

module Kupo
  class RootCommand < Clamp::Command
    banner "kupo (クポ) - Kontena Kubernetes distribution installer, kupo!"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand
    subcommand ["version"], "Show version information", VersionCommand

    def self.run
      super
    rescue StandardError => exc
      warn exc.message
      warn exc.backtrace.join("\n")
    end
  end
end
