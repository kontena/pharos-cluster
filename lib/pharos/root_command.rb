# frozen_string_literal: true

require_relative 'up_command'
require_relative 'version_command'

module Pharos
  class RootCommand < Clamp::Command
    banner "pharos-cluster - Kontena Pharos cluster manager"

    subcommand ["build", "up"], "Initialize/upgrade cluster", UpCommand
    subcommand ["version"], "Show version information", VersionCommand
  end
end
