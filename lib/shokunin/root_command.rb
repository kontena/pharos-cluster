require_relative 'up_command'
require_relative 'version_command'

module Shokunin
  class RootCommand < Clamp::Command

    banner "職人 - kubernetes cluster artisan"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand
    subcommand ["version"], "Show version information", VersionCommand

    def self.run
      super()
    rescue => exc
      $stderr.puts exc.message
    end
  end
end
