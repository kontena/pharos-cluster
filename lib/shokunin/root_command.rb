require_relative 'up_command'

module Shokunin
  class RootCommand < Clamp::Command

    banner "職人 - kubernetes cluster artisan"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand

    def self.run
      super
    rescue => exc
      $stderr.puts exc.message
    end
  end
end
