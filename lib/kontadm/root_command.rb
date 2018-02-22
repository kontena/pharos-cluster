require_relative 'up_command'

module Kontadm
  class RootCommand < Clamp::Command
    subcommand "up", "Initialize/upgrade cluster", UpCommand
  end
end
