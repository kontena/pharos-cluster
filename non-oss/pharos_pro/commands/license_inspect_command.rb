# frozen_string_literal: true

module Pharos
  class LicenseInspectCommand < Pharos::Command
    options :license_key
    option %w(-q --quiet), :flag, 'exit with error status when license is not valid'

    def execute
      exit 1 if quiet? && !jwt_token.valid?

      puts decorate_license

      if jwt_token.valid?
        puts "\n" + pastel.green("License is valid") if $stdout.tty?
      else
        signal_error pastel.red("License is NOT valid")
      end
    end
  end
end
