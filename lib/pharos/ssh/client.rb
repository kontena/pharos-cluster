# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'shellwords'

module Pharos
  module SSH
    Error = Class.new(StandardError)

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

      attr_reader :session

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

      # @example
      #   tempfile do |tmp|
      #     exec!("less #{tmp}")
      #   end
      # @example
      #   tmp = tempfile.new(content: "hello")
      #   exec!("cat #{tmp}")
      #   tmp.unlink
      #
      # @param prefix [String] tempfile filename prefix (default "pharos")
      # @param content [String] initial file content, default blank
      # @param file [String,IO] path to local file or a readable IO object
      # @return [Pharos::SSH::Tempfile]
      # @yield [Pharos::SSH::Tempfile]
      def tempfile(prefix: "pharos", content: nil, file: nil, &block)
        Tempfile.new(self, prefix: prefix, content: content, file: file, &block)
      end

      # @param cmd [String] command to execute
      # @return [Pharos::Command::Result]
      def exec(cmd, **options)
        require_session!
        RemoteCommand.new(self, cmd, **options).run
      end

      # @param cmd [String] command to execute
      # @raise [Pharos::SSH::RemoteCommand::ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        require_session!
        RemoteCommand.new(self, cmd, **options).run!.stdout
      end

      # @param script [String] name of script
      # @param path [String] real path to file, defaults to script
      # @raise [Pharos::SSH::RemoteCommand::ExecError]
      # @return [String] stdout
      def exec_script!(name, env: {}, path: nil, **options)
        script = File.read(path || name)
        cmd = %w(sudo)
        env.each { |key, value| cmd << "#{key}=#{value.shellescape}" }
        cmd.concat %w(sh -x)
        exec!(cmd, stdin: script, debug_source: name, **options)
      end

      # @param cmd [String] command to execute
      # @return [Boolean]
      def exec?(cmd, **options)
        exec(cmd, **options).success?
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

      def file(path)
        Pharos::SSH::RemoteFile.new(self, path)
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
