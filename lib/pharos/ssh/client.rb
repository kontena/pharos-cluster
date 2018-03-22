# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'shellwords'

module Pharos
  module SSH
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

    class Exec
      INDENT = "    "

      def self.debug?
        ENV['DEBUG'].to_s == 'true'
      end

      attr_reader :cmd, :exit_status, :stdout, :stderr, :output

      def initialize(cmd, stdin: nil, debug: self.class.debug?, debug_source: nil)
        @cmd = cmd
        @stdin = stdin
        @debug = debug
        @debug_source = debug_source

        @exit_status = nil
        @stdout = ''
        @stderr = ''
        @output = ''
      end

      # @param session [Net::SSH::Connection::Session]
      def open(session)
        @channel = session.open_channel do |channel|
          start(channel)
        end
      end

      def wait
        @channel.wait
      end

      # @param channel [Net::SSH::Connection::Channel]
      def start(channel)
        debug_cmd(@cmd, source: @debug_source) if debug?

        channel.exec @cmd do |_, success|
          raise Error, "Failed to exec #{cmd}" unless success

          channel.on_data do |_, data|
            @stdout += data
            @output += data

            debug_stdout(data) if debug?
          end
          channel.on_extended_data do |_c, _type, data|
            @stderr += data
            @output += data

            debug_stderr(data) if debug?
          end
          channel.on_request("exit-status") do |_, data|
            @exit_status = data.read_long

            debug_exit(@exit_status) if debug?
          end

          if @stdin
            channel.send_data(@stdin)
            channel.eof!
          end
        end
      end

      # @return [Boolean]
      def error?
        !@exit_status.zero?
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

    class Client
      # @param host [Pharos::Configuration::Host]
      def self.for_host(host)
        @connections ||= {}
        unless @connections[host]
          @connections[host] = new(host.address, host.user, keys: [host.ssh_key_path])
          @connections[host].connect
        end

        @connections[host]
      end

      def self.disconnect_all
        return unless @connections

        @connections.values.map(&:disconnect)
      end

      def initialize(host, user = nil, opts = {})
        @host = host
        @user = user
        @opts = opts
      end

      def logger
        @logger ||= Logger.new($stderr).tap do |logger|
          logger.progname = "SSH[#{@host}]"
          logger.level = ENV["DEBUG_SSH"] ? Logger::DEBUG : Logger::INFO
        end
      end

      def connect
        logger.debug { "connect: #{@user}@#{@host} (#{@opts})" }
        @session = Net::SSH.start(@host, @user, @opts)
      end

      # @param cmd [String] command to execute
      # @return [Exec]
      def exec(cmd, **options)
        require_session!

        logger.debug { "exec: #{cmd}" }

        ex = Exec.new(cmd, **options)
        ex.open(@session)
        ex.wait
        ex
      end

      # @param cmd [String] command to execute
      # @raise [ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        ex = exec(cmd, **options)

        raise ExecError.new(cmd, ex.exit_status, ex.output) if ex.error?

        ex.stdout
      end

      # @param script [String] name of script
      # @param path [String] real path to file, defaults to script
      # @raise [ExecError]
      # @return [String] stdout
      def exec_script!(name, env: {}, path: nil, **options)
        script = File.read(path || name)
        cmd = ['sudo']

        env.each_pair do |e, value|
          cmd << "#{e}=#{Shellwords.escape(value)}"
        end

        cmd << 'sh'
        cmd << '-x'

        ex = exec(cmd.join(' '), stdin: script, debug_source: name, **options)

        raise ExecError.new(name, ex.exit_status, ex.output) if ex.error?

        ex.stdout
      end

      # @param cmd [String] command to execute
      # @return [Boolean]
      def exec?(cmd, **options, &block)
        ex = exec(cmd, **options, &block)

        !ex.error?
      end

      # @param local_path [String]
      # @param remote_path [String]
      # @param opts [Hash]
      def upload(local_path, remote_path, opts = {})
        require_session!
        logger.debug "upload from #{local_path}: #{remote_path}"
        @session.scp.upload!(local_path, remote_path, opts)
      end

      # @param remote_path [String]
      # @param local_path [String]
      # @param opts [Hash]
      def download(remote_path, local_path, opts = {})
        require_session!
        logger.debug "download to #{local_path}: #{remote_path}"
        @session.scp.download!(remote_path, local_path, opts)
      end

      # @param path [String]
      # @return [Boolean]
      def file_exists?(path)
        # TODO: this gives a false negative if we don't have access to the directory
        exec?("[ -e #{path} ]")
      end

      # @param path [String]
      # @return [String]
      def read_file(path)
        exec!("sudo cat #{path}")
      end

      # @param path [String]
      # @return [String]
      def write_file(path, contents, prefix: 'kupo')
        tmp_file = tempfile(prefix: prefix, content: contents)
        exec!("sudo mv #{tmp_file} #{path} || rm #{tmp_path}")
      end

      def disconnect
        @session.close if @session && !@session.closed?
      end

      private

      def require_session!
        raise Error, "Connection not established" unless @session
      end
    end
  end
end
