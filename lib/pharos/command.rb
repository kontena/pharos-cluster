# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    option '--[no-]color', :flag, "colorize output", default: $stdout.tty?

    option ['-v', '--version'], :flag, "print #{File.basename($PROGRAM_NAME)} version" do
      puts "#{File.basename($PROGRAM_NAME)} #{Pharos::VERSION}"
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

    def subcommand_missing(subcommand)
      require 'mkmf'
      plugin_subcommand = find_executable "pharos-#{subcommand}" # TODO: this quick-which-hack outputs to terminal and leaves behind a mkmf.log
      signal_usage_error "Unknown subcommand: #{subcommand}" unless plugin_subcommand
      ruby_path = RbConfig::CONFIG['bindir']
      ENV.update(
        'PHAROS_RUBY_PATH' => ruby_path,
        'PHAROS_BIN_PATH' => File.expand_path(File.dirname(File.expand_path($PROGRAM_NAME))),
        'PHAROS_BIN' => File.expand_path($PROGRAM_NAME),
        'PHAROS_VERSION' => Pharos::VERSION
      )
      exec(plugin_subcommand, *ARGV[1..-1])
    end
  end
end
