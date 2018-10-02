# frozen_string_literal: true

require "pharos/command"
require "pharos/root_command"

require_relative "backup_create_command"
require_relative "backup_list_command"
require_relative "backup_describe_command"

module Pharos
  class BackupCommand < Pharos::Command
    subcommand "create", "Create backup", Pharos::BackupCreateCommand
    subcommand "list", "List existing backups", Pharos::BackupListCommand
    subcommand "describe", "Describe existing backup", Pharos::BackupDescribeCommand
  end
end

Pharos::RootCommand.register('backup', "Manage cluster backups", Pharos::BackupCommand)
