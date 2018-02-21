require_relative 'up_command'

module Kuntena
  class RootCommand < Clamp::Command
    subcommand "up", "Initialize/upgrade cluster", UpCommand
  end
end
