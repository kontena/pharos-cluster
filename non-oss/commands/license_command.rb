# frozen_string_literal: true

require_relative 'license_assign_command'

module Pharos
  class LicenseCommand < Pharos::Command
    banner "Kontena Pharos license subcommands"

    subcommand "assign", "assign a license key to a cluster", LicenseAssignCommand

    Pharos::RootCommand.subcommand "license", "manage kontena pharos licenses", self
  end
end
