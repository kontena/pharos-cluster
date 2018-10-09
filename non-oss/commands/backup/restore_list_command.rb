# frozen_string_literal: true

require_relative 'client_helper'

module Pharos
  class RestoreListCommand < Pharos::Command
    include ClientHelper

    banner "List existing cluster restores"

    def execute
      table = TTY::Table.new %w{NAME STATUS CREATED}, []
      client.api('ark.heptio.com/v1').resource('restores', namespace: 'kontena-backup').list.each do |restore|
        table << [restore.metadata.name, restore.status.phase, restore.metadata.creationTimestamp]
      end
      puts table.render(:basic)
    rescue StandardError => exc
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
