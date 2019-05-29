# frozen_string_literal: true

require 'shellwords'

module Pharos
  module Transport
    module Command
      class Local
        attr_reader :cmd, :result

        # @param client [Pharos::Transport::Local] client instance
        # @param cmd [String,Array<String>] command to execute
        # @param timeout [Integer,NilClass] max seconds to allow the command to run
        # @param stdin [String,IO] attach string or stream to command STDIN
        # @param source [String]
        def initialize(client, cmd, timeout: 600, stdin: nil, source: nil)
          @timeout = timeout.to_i
          @client = client
          @cmd = "env bash --noprofile --norc -x -c #{(cmd.is_a?(Array) ? cmd.join(' ') : cmd).shellescape}"
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
          with_timeout do
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

        private

        def with_timeout
          return yield unless @timeout.positive?

          start_time = Time.now

          thread = Thread.new do
            Thread.current.report_on_exception = false
            yield
          end

          extra_time_start = nil
          kill_switch_engage = true

          loop do
            break unless thread.alive?

            sleep 0.1 unless extra_time_start

            next if !kill_switch_engage || Time.now - start_time < @timeout

            if !$stdin.tty?
              warn "Command timeout reached"
              thread.raise Timeout::Error
              break
            elsif extra_time_start.nil?
              warn "Command timeout reached, to cancel automatic termination, press any key in 30 seconds"
              extra_time_start = Time.now
            end

            if extra_time_start && Time.now - extra_time_start < 30
              $stdin.noecho do
                $stdin.raw do
                  if $stdin.wait_readable(0.1) && $stdin.getc
                    kill_switch_engage = false
                    puts "Automatic termination canceled"
                  end
                end
              end
            else
              thread.raise Timeout::Error
              break
            end
          end

          thread.value
        end
      end
    end
  end
end
