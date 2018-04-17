# frozen_string_literal: true

require 'logger'

module Pharos
  # Pharos message output handler
  class Output
    extend Forwardable

    STDOUT_FORMATTER = proc do |severity, _datetime, progname, msg|
      if severity == "ANY"
        "%<msg>s\n" % { msg: msg }
      elsif progname.nil?
        "    %<msg>s\n" % { msg: msg }
      else
        "    %<msg>s %<prg>s\n" % { msg: msg, prg: "(#{dim(progname)})" }
      end
    end

    def initialize
      @pastel = Pastel.new(enabled: $stdout.tty?)
      configure_logger
    end

    def configure_logger
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @logger.formatter = STDOUT_FORMATTER if $stdout.tty?
    end

    def_delegators :@logger, :debug, :info, :warn, :error, :fatal
    def_delegators :@logger, :debug?, :info?, :warn?, :error?, :fatal?

    # rubocop:disable Lint/UnneededSplatExpansion
    def_delegators :@pastel, *%i(
      black red green yellow blue magenta cyan white bright_black bright_red
      bright_green bright_yellow bright_blue bright_magenta bright_cyan
      bright_white on_black on_red on_green on_yellow on_blue on_magenta
      on_cyan on_white on_bright_black on_bright_red on_bright_green
      on_bright_yellow on_bright_blue on_bright_magenta on_bright_cyan
      on_bright_white clear bold dim italic underline inverse hidden
      strikethrough
    )
    # rubocop:enable Lint/UnneededSplatExpansion

    # Writes to logdev without formatting. Returns self for piping.
    # @example
    #   Out << "hello" << "there" << "\n"
    # @param msg [String]
    # @return [Pharos::Output]
    def <<(msg)
      @logger << msg
      self
    end

    # Set debug on/off
    # @param [TrueClass,FalseClass]
    def debug=(bool)
      @logger.level = bool ? Logger::DEBUG : Logger::INFO
    end

    # Set color on/off
    # @param [TrueClass,FalseClass]
    def color=(bool)
      @pastel = Pastel.new(enabled: bool)
    end

    # Outputs the message using logger severity 6. These are messages
    # that are expected to be printed with any output level.
    # @param arg [String] progname or message. Use block to pass message when using progname.
    def puts(arg, &block)
      if block_given?
        @logger.add(6, nil, arg, &block)
      else
        @logger.add(6, arg)
      end
    end

    # Outputs message to stderr when $stdout or $stderr is piped.
    # When $stdout and $stderr are regular terminals, outputs as a normal error message
    # @param arg [String] progname or message. Use block to pass message when using progname.
    def error(arg, &block)
      if !$stderr.tty? || !$stdout.tty?
        msg = block_given? ? "[#{arg}] #{yield}" : arg
        warn($stderr.tty? ? msg : @pastel.undecorate(msg))
      else
        @logger.error(arg, &block)
      end
    end

    # A green top level message
    # @param msg [String]
    def header(msg)
      self.puts(green('==> %<msg>s' % { msg: msg }))
    end

    # A cyan top level message
    # @param msg [String]
    def sub_header(msg)
      self.puts(cyan('==> %<msg>s' % { msg: msg }))
    end
  end
end
