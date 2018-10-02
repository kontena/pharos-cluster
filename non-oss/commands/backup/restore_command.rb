# frozen_string_literal: true

require "pharos/command"
require "pharos/root_command"

require_relative "restore_create_command"
require_relative "restore_list_command"
require_relative "restore_describe_command"

module Pharos
  class RestoreCommand < Pharos::Command
    subcommand "create", "Start restore", Pharos::RestoreCreateCommand
    subcommand "list", "List existing restores", Pharos::RestoreListCommand
    subcommand "describe", "Describe existing restore", Pharos::RestoreDescribeCommand
  end
end

Pharos::RootCommand.register('restore', "Manage cluster backups", Pharos::RestoreCommand)
