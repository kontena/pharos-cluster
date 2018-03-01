require_relative 'up_command'
require_relative 'version_command'

module Kupo
  class RootCommand < Clamp::Command

    banner "kupo (クポ) - Kontena Kubernetes distribution installer, kupo!"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand
    subcommand ["version"], "Show version information", VersionCommand

    def self.run
      super
    rescue => exc
      $stderr.puts exc.message
      $stderr.puts exc.backtrace.join("\n")
    end
  end
end
