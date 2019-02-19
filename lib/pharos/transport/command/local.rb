# frozen_string_literal: true

module Pharos
  module Transport
    module Command
      class Local
        attr_reader :cmd, :result

        # @param client [Pharos::Transport::Local] client instance
        # @param cmd [String,Array<String>] command to execute
        # @param stdin [String,IO] attach string or stream to command STDIN
        # @param source [String]
        def initialize(client, cmd, stdin: nil, source: nil)
          @client = client
          @cmd = cmd.is_a?(Array) ? cmd.join(' ') : cmd
          @stdin = stdin.respond_to?(:read) ? stdin.read : stdin
          @source = source
          @result = Pharos::Transport::Command::Result.new(hostname)
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

        # @return [Pharos::Transport::Command::Result]
        def run
          result.append(@source.nil? ? @cmd : "#{@cmd} < #{@source}", :cmd)
          Open3.popen3(@cmd) do |stdin, stdout, stderr, wait_thr|
            unless stdin.closed?
              stdin.write(@stdin) if @stdin
              stdin.close
            end

            until [stdout, stderr].all?(&:eof?)
              readable = IO.select([stdout, stderr])
              next unless readable&.first

              readable.first.each do |stream|
                data = +''
                # rubocop:disable Lint/HandleExceptions
                begin
                  stream.read_nonblock(1024, data)
                rescue EOFError
                  # ignore, it's expected for read_nonblock to raise EOFError
                  # when all is read
                end
                # rubocop:enable Lint/HandleExceptions
                result.append(data, stream == stdout ? :stdout : :stderr) unless data.empty?
              end
            end
            result.exit_status = wait_thr.value.exitstatus
          end
          result
        end
      end
    end
  end
end
