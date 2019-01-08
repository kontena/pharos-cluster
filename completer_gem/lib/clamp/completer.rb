require "clamp/completer/version"
require 'shellwords'

module Clamp
  module Completer
    module Builder
      autoload :ERB, 'erb'
      autoload :OpenStruct, 'ostruct'

      class Iterator
        def initialize(root)
          @root = root
        end

        def recurse(base = [], &block)
          if @root.has_subcommands?
            @root.recognised_subcommands.each do |sc|
              sc.names.each do |name|
                Iterator.new(sc.subcommand_class).recurse(base + [name], &block)
              end
            end
          end
          yield(base, @root) unless base.empty?
        end
      end

      def root
        self.class.root_command
      end

      def template_path(shell_name)
        File.join(__dir__, 'completer', 'templates', "#{shell_name}.sh.erb")
      end

      def wrapper
        klass = Class.new(self.class)
        klass.subcommand(File.basename($PROGRAM_NAME), root.description || "main", root)
        klass
      end

      def execute
        template_file = template_path(shell)
        unless File.exist?(template_file)
          warn "Completion generation is not supported for #{shell}, defaulting to bash"
          template_file = template_path("bash")
        end

        puts ERB.new(File.read(template_file), nil, '%-').tap { |e| e.location = [template_file, nil] }.result(
                         OpenStruct.new(progname: File.basename($PROGRAM_NAME), iterator: Iterator.new(wrapper)).instance_eval { binding }
        )
      end
    end

    def self.new(root_command, inherit_from: Clamp::Command)
      @klass = Class.new(inherit_from) do
        include Builder

        class << self
          attr_accessor :root_command
        end
      end

      @klass.parameter('[SHELL]', 'shell', environment_variable: 'SHELL', default: 'bash') do |shell|
        File.basename(shell)
      end

      @klass.root_command = root_command

      @klass.banner("To load, use: source <(#{File.basename($PROGRAM_NAME)} complete #{@klass.usage_descriptions.join(' ')})")
      @klass
    end
  end
end
