# frozen_string_literal: true

require 'shellwords'

module Pharos
  module Transport
    module Command
      class Local
        EXPORT_ENVS = {
          http_proxy: '$http_proxy',
          https_proxy: '$https_proxy',
          no_proxy: '$no_proxy',
          HTTP_PROXY: '$HTTP_PROXY',
          HTTPS_PROXY: '$HTTPS_PROXY',
          NO_PROXY: '$NO_PROXY',
          FTP_PROXY: '$FTP_PROXY',
          PATH: '$PATH'
        }.freeze

        attr_reader :cmd, :result, :env

        # @param client [Pharos::Transport::Local] client instance
        # @param cmd [String,Array<String>] command to execute
        # @param env [Hash] environment variables hash
        # @param stdin [String,IO] attach string or stream to command STDIN
        # @param source [String]
        def initialize(client, cmd, stdin: nil, source: nil, env: {})
          @client = client
          @source = source
          @stdin = stdin.respond_to?(:read) ? stdin.read : stdin
          @env = EXPORT_ENVS.merge(@client.host.environment || {}).merge(env)

          cmd = cmd.join(' ') if cmd.is_a?(Array)

          cmd_parts = ['env', '-i', *envs_array, 'bash', '--norc', '--noprofile', '-x']

          if cmd.nil?
            cmd_parts.insert(0, 'sudo')
          else
            cmd_parts.concat(['-c', "sudo() { $(which sudo) -E \"$@\"; }; export -f sudo; #{cmd}".shellescape])
          end

          cmd_parts << '-s' unless stdin.nil?

          @cmd = cmd_parts.join(' ')

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

        private

        # @return [Array<String>]
        def envs_array
          env.map { |k, v| "#{k}=\"#{v}\"" }
        end
      end
    end
  end
end
