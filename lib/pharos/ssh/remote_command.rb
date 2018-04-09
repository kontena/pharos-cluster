# frozen_string_literal: true

module Pharos
  module SSH
    class RemoteCommand
      Error = Class.new(StandardError)

      class ExecError < Error
        attr_reader :cmd, :exit_status, :output

        def initialize(cmd, exit_status, output)
          @cmd = cmd
          @exit_status = exit_status
          @output = output
        end

        def message
          "SSH exec failed with code #{@exit_status}: #{@cmd}\n#{@output}"
        end
      end

      class Result
        attr_reader :stdin, :stdout, :stderr, :output
        attr_accessor :exit_status

        def initialize
          @stdin = +''
          @stdout = +''
          @stderr = +''
          @output = +''
          @exit_status = -127
        end

        def success?
          exit_status.zero?
        end

        def error?
          !success?
        end
      end

      INDENT = "    "

      def self.debug?
        ENV['DEBUG'].to_s == 'true'
      end

      attr_reader :cmd

      def initialize(client, cmd, stdin: nil, debug: self.class.debug?, debug_source: nil)
        @client = client
        @cmd = cmd.is_a?(Array) ? cmd.join(' ') : cmd
        @stdin = stdin.respond_to?(:read) ? stdin.read : stdin
        @debug = debug
        @debug_source = debug_source
        @exit_status = nil
      end

      def run!
        result = run
        raise ExecError.new(cmd, result.exit_status, result.output) if result.error?
        result
      end

      def run
        debug_cmd(@cmd, source: @debug_source) if debug?

        result = Result.new

        response = @client.session.open_channel do |channel|
          channel.exec @cmd do |_, success|
            raise Error, "Failed to exec #{cmd}" unless success

            channel.on_data do |_, data|
              result.stdout << data
              result.output << data

              debug_stdout(data) if debug?
            end

            channel.on_extended_data do |_c, _type, data|
              result.stderr << data
              result.output << data

              debug_stderr(data) if debug?
            end

            channel.on_request("exit-status") do |_, data|
              result.exit_status = data.read_long

              debug_exit(result.exit_status) if debug?
            end

            if @stdin
              channel.send_data(@stdin)
              channel.eof!
            end
          end
        end

        response.wait

        result
      end

      def debug?
        @debug
      end

      def pastel
        @pastel ||= Pastel.new
      end

      def debug_cmd(cmd, source: nil)
        $stdout.write(INDENT + pastel.cyan("$ #{cmd}" + (source ? " < #{source}" : "")) + "\n")
      end

      def debug_stdout(data)
        data.each_line do |line|
          $stdout.write(INDENT + pastel.dim(line.to_s))
        end
      end

      def debug_stderr(data)
        data.each_line do |line|
          # TODO: stderr is not line-buffered, this indents each write
          $stdout.write(INDENT + pastel.red(line.to_s))
        end
      end

      def debug_exit(exit_status)
        $stdout.write(INDENT + pastel.yellow("! #{exit_status}") + "\n")
      end
    end
  end
end
