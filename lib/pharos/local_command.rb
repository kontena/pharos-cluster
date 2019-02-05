# frozen_string_literal: true

module Pharos
  class LocalCommand
    attr_reader :cmd, :result

    # @param client [Pharos::SSH::Client] ssh client instance
    # @param cmd [String,Array<String>] command to execute
    # @param stdin [String,IO] attach string or stream to command STDIN
    # @param source [String]
    def initialize(client, cmd, stdin: nil, source: nil)
      @client = client
      @cmd = cmd.is_a?(Array) ? cmd.join(' ') : cmd
      @stdin = stdin.respond_to?(:read) ? stdin.read : stdin
      @source = source
      @result = Pharos::CommandResult.new(hostname)
      freeze
    end

    def hostname
      "localhost"
    end

    # @return [Boolean] success or failure?
    def run?
      run.success?
    end

    # @return [Result]
    # @raise [Pharos::ExecError]
    def run!
      run.tap do |result|
        raise Pharos::ExecError.new(@source || cmd, result.exit_status, result.output) if result.error?
      end
    end

    # @return [Pharos::CommandResult]
    def run
      result.append(@source.nil? ? @cmd : "#{@cmd} < #{@source}", :cmd)
      result.append(@stdin, :stdin) if @stdin
      stdout, stderr, status = Open3.capture3(@cmd, stdin_data: @stdin)
      result.append(stdout, :stdout)
      result.append(stderr, :stderr)
      result.exit_status = status.exitstatus
      result
    end
  end
end
