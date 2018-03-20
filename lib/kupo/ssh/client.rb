# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'

module Kupo
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

      def initialize(cmd, debug: self.class.debug?)
        @cmd = cmd
        @debug = debug

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
        debug_cmd(@cmd) if debug?

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
        end
      end

      # @return [Boolean]
      def error?
        !@exit_status.zero?
      end

      # @return [ExecError]
      def error
        ExecError.new(@cmd, @exit_status, @output)
      end

      # @raise [ExecError]
      def error!
        raise error
      end

      def debug?
        @debug
      end

      def pastel
        @pastel ||= Pastel.new
      end

      def debug_cmd(cmd)
        $stdout.write(INDENT + pastel.cyan("$ #{cmd}") + "\n")
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
      # @param host [Kupo::Configuration::Host]
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
      def exec(cmd)
        require_session!

        logger.debug { "exec: #{cmd}" }

        ex = Exec.new(cmd)
        ex.open(@session)
        ex.wait
        ex
      end

      # @param cmd [String] command to execute
      # @raise [ExecError]
      # @return [String] stdout
      def exec!(cmd)
        ex = exec(cmd)

        raise ex.error if ex.error?

        ex.stdout
      end

      # @param cmd [String] command to execute
      # @return [Boolean]
      def exec?(cmd, &block)
        ex = exec(cmd, &block)

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
        exec?("[ -e #{path} ]")
      end

      # @param path [String]
      # @return [String]
      def file_contents(path)
        exec!("sudo cat #{path}")
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
