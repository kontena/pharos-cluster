# frozen_string_literal: true

module Pharos
  class CommandResult
    attr_reader :stdin, :stdout, :stderr, :output, :hostname, :exit_status

    def initialize(hostname)
      @hostname = hostname
      @stdin = +''
      @stdout = +''
      @stderr = +''
      @output = +''
      @exit_status = -127
      initialize_debug
    end

    def exit_status=(exitstatus)
      @exit_status = exitstatus
      debug { debug_exit(exitstatus) }
    end

    def append(string, stream = :stdout)
      case stream
      when :cmd
        @cmd = string
        debug { debug_cmd(string) }
      when :stdin
        stdin << string
        debug { debug_stdin(string) }
      when :stdout
        stdout << string
        output << string
        debug { debug_stdout(string) }
      when :stderr
        stderr << string
        output << string
        debug { debug_stderr(string) }
      end
    end

    def success?
      exit_status.zero?
    end

    def error?
      !success?
    end

    def initialize_debug
      if !ENV['DEBUG'].to_s.empty?
        @pastel = Pastel.new(enabled: $stdout.tty?)
        @debug_prefix = "    #{@pastel.dim("#{hostname}:")} "
      else
        define_method :debug do
          nil
        end
      end
    end

    # @return [Boolean]
    def debug?
      @debug
    end

    def debug
      yield
    end

    # @param cmd [String]
    # @return [Integer]
    def debug_cmd(cmd)
      $stdout << @debug_prefix << @pastel.cyan("$ #{cmd}") << "\n"
    end

    # @param data [String]
    # @return [Integer]
    def debug_stdin(data)
      return if ENV["DEBUG_STDIN"].to_s.empty?
      $stdout << @debug_prefix << @pastel.green("< #{data}") << "\n"
    end

    # @param data [String]
    # @return [String]
    def debug_stdout(data)
      data.each_line do |line|
        $stdout << @debug_prefix << @pastel.dim(line.to_s)
      end
    end

    # @param data [String]
    # @return [String]
    def debug_stderr(data)
      data.each_line do |line|
        # TODO: stderr is not line-buffered, this indents each write
        $stdout << @debug_prefix << @pastel.red(line.to_s)
      end
    end

    # @param exit_status [Integer]
    # @return [Integer]
    def debug_exit(exit_status)
      $stdout << @debug_prefix << @pastel.yellow("! #{exit_status}") << "\n"
    end
  end
end
