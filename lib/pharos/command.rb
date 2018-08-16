# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    option '--[no-]color', :flag, "colorize output", default: $stdout.tty?

    option ['-v', '--version'], :flag, "print pharos-cluster version" do
      puts "pharos-cluster #{Pharos::VERSION}"
      exit 0
    end

    option ['-d', '--debug'], :flag, "enable debug output", environment_variable: "DEBUG" do
      ENV["DEBUG"] = "true"
    end

    def pastel
      @pastel ||= Pastel.new(enabled: color?)
    end

    def prompt
      @prompt ||= TTY::Prompt.new(enable_color: color?)
    end

    def rouge
      @rouge ||= Rouge::Formatters::Terminal256.new(Rouge::Themes::Github.new)
    end

    def tty?
      $stdin.tty?
    end

    def stdin_eof?
      $stdin.eof?
    end
  end
end
