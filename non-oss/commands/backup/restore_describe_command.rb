# frozen_string_literal: true

require "k8s-client"
require_relative 'client_helper'

module Pharos
  class RestoreDescribeCommand < Pharos::Command
    include ClientHelper
    using Pharos::CoreExt::DeepTransformKeys

    banner "Describe a backup details"

    parameter "NAME", "Name of the backup"

    def execute
      backup = client.api('ark.heptio.com/v1').resource('restores', namespace: 'kontena-backup').get(name)
      puts ::YAML.dump(backup.to_hash.deep_stringify_keys)
    rescue StandardError => exc
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{exc.class.name} : #{exc.message}"
      exit 1
    end
  end
end
