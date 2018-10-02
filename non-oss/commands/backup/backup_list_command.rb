# frozen_string_literal: true

require "k8s-client"
require_relative 'client_helper'
require 'tty-table'

module Pharos
  class BackupListCommand < Pharos::Command
    include ClientHelper

    banner "List existing cluster backups"

    def execute
      table = TTY::Table.new %w{NAME STATUS CREATED EXPIRES PHAROS_VERSION}, []
      client.api('ark.heptio.com/v1').resource('backups', namespace: 'kontena-backup').list.each do |backup|
        table << [backup.metadata.name, backup.status.phase, backup.status.completionTimestamp, backup.spec.ttl, backup.metadata.annotations&.dig('pharos.kontena.io/version')]
      end
      puts table.render(:basic)
    rescue StandardError => exc
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
