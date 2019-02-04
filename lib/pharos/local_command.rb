# frozen_string_literal: true

module Pharos
  class LocalCommand
    Error = Class.new(StandardError)

    class ExecError < Error
      attr_reader :cmd, :exit_status, :output

      def initialize(cmd, exit_status, output)
        @cmd = cmd
        @exit_status = exit_status
        @output = output
      end

      def message
        "Local exec failed with code #{@exit_status}: #{@cmd}\n#{@output}"
      end
    end

    def self.debug?
      @debug ||= !ENV['DEBUG'].to_s.empty?
    end

    INDENT = "    "

    attr_reader :cmd

    # @param client [Pharos::SSH::Client] ssh client instance
    # @param cmd [String,Array<String>] command to execute
    # @param stdin [String,IO] attach string or stream to command STDIN
    # @param source [String]
    def initialize(client, cmd, stdin: nil, source: nil)
      @client = client
      @cmd = cmd.is_a?(Array) ? cmd.join(' ') : cmd
      @stdin = stdin.respond_to?(:read) ? stdin.read : stdin
      @source = source
      initialize_debug
      freeze
    end

    # @return [Result]
    # @raises [ExecError] if result errors
    def run!
      result = run
      raise ExecError.new(@source || cmd, result.exit_status, result.output) if result.error?
      result
    end

    # @return [Pharos::SSH::RemoteCommand::Result]
    def run
      debug_cmd(@cmd, source: @source) if debug?

      result = Pharos::SSH::RemoteCommand::Result.new
      stdout, stderr, status = Open3.capture3(@cmd, stdin_data: @stdin)
      result.stdout << stdout
      result.stderr << stderr
      result.exit_status = status.exitstatus
      debug_stdout(stdout) if debug?
      debug_stderr(stderr) if debug?
      debug_exit(status.exitstatus) if debug?
      result
    end

    private

    attr_reader :pastel

    def initialize_debug
      if self.class.debug?
        @debug = true
        @pastel = Pastel.new(enabled: $stdout.tty?)
      else
        @debug = false
      end
    end

    # @return [Boolean]
    def debug?
      @debug
    end

    # @param cmd [String]
    # @param source [String, NilClass]
    # @return [Integer]
    def debug_cmd(cmd, source: nil)
      $stdout.write("#{INDENT} #{pastel.cyan("localhost:")} #{pastel.cyan("$ #{cmd}")}\n")
    end

    # @param data [String]
    # @return [String]
    def debug_stdout(data)
      data.each_line do |line|
        $stdout.write("#{INDENT} #{pastel.dim("localhost:")} #{pastel.dim(line.to_s)}")
      end
    end

    # @param data [String]
    # @return [String]
    def debug_stderr(data)
      data.each_line do |line|
        $stdout.write("#{INDENT} #{pastel.dim("localhost:")} #{pastel.red(line.to_s)}")
      end
    end

    # @param exit_status [Integer]
    # @return [Integer]
    def debug_exit(exit_status)
      $stdout.write("#{INDENT} #{pastel.dim("localhost:")} #{pastel.yellow("! #{exit_status}")}\n")
    end
  end
end

