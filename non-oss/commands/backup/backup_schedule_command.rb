# frozen_string_literal: true

require "pharos/command"
require "pharos/root_command"

require_relative "backup_schedule_create_command"
require_relative "backup_schedule_list_command"
require_relative "backup_schedule_describe_command"

module Pharos
  class BackupScheduleCommand < Pharos::Command
    subcommand "create", "Start restore", Pharos::BackupScheduleCreateCommand
    subcommand "list", "List existing restores", Pharos::BackupScheduleListCommand
    subcommand "describe", "Describe existing restore", Pharos::BackupScheduleDescribeCommand
  end
end

Pharos::RootCommand.register('backup-schedule', "Manage cluster backup schedules", Pharos::BackupScheduleCommand)
