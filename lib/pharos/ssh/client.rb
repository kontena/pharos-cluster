# frozen_string_literal: true

require 'net/ssh'
require 'shellwords'

module Pharos
  module SSH
    Error = Class.new(StandardError)

    class Client
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
      # @param content [String,IO] initial file content, default blank
      # @return [Pharos::SSH::Tempfile]
      # @yield [Pharos::SSH::Tempfile]
      def tempfile(prefix: "pharos", content: nil, &block)
        Tempfile.new(self, prefix: prefix, content: content, &block)
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
        exec!(cmd, stdin: script, source: name, **options)
      end

      # @param cmd [String] command to execute
      # @return [Boolean]
      def exec?(cmd, **options)
        exec(cmd, **options).success?
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
