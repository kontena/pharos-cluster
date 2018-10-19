# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    include Pharos::Logging

    # @param [Array<Symbol>] a list of CommandOption module names in snake_case, for example :filtered_hosts
    def self.options(*option_names)
      option_names.each do |option_name|
        module_name = option_name.to_s.extend(Pharos::CoreExt::StringCasing).camelcase.to_sym
        send(:include, Pharos::CommandOptions.const_get(module_name))
      end
    end

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
  end
end
