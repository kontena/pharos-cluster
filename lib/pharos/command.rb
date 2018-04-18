# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    option '--[no-]color', :flag, "Colorize output", default: $stdout.tty? do |bool|
      Out.color = bool
    end

    option ['-v', '--version'], :flag, "print pharos-cluster version" do
      puts "pharos-cluster #{Pharos::VERSION}"
      exit 0
    end

    option ['-d', '--debug'], :flag, "enable debug output", environment_variable: "DEBUG" do
      Out.debug = true
    end

    option ['-V', '--verbose'], :flag, "enable verbose output" do
      Out.verbose = true
    end
  end
end
