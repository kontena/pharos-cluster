# frozen_string_literal: true

require_relative 'client_helper'

module Pharos
  class BackupScheduleListCommand < Pharos::Command
    include ClientHelper

    banner "List existing cluster backup schedules"

    def execute
      table = TTY::Table.new %w{NAME STATUS CREATED SCHEDULE LAST_BACKUP}, []
      client.api('ark.heptio.com/v1').resource('schedules', namespace: 'kontena-backup').list.each do |schedule|
        table << [schedule.metadata.name, schedule.status.phase, schedule.metadata.creationTimestamp, schedule.spec.schedule, schedule.status.lastBackup]
      end
      puts table.render(:basic)
    rescue StandardError => exc
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
