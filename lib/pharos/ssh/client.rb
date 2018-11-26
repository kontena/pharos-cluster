# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/gateway'
require 'shellwords'

module Pharos
  module SSH
    Error = Class.new(StandardError)

    EXPORT_ENVS = {
      http_proxy: '$http_proxy',
      HTTP_PROXY: '$HTTP_PROXY',
      HTTPS_PROXY: '$HTTPS_PROXY',
      NO_PROXY: '$NO_PROXY',
      PATH: '$PATH'
    }.freeze

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

      def bastion
        @bastion ||= @opts.delete(:bastion)
      end

      def connect
        logger.debug { "connect: #{@user}@#{@host} (#{@opts})" }
        if bastion
          gw_opts = {}
          gw_opts[:keys] = [bastion.ssh_key_path] if bastion.ssh_key_path
          gateway = Net::SSH::Gateway.new(bastion.address, bastion.user, gw_opts)
          @session = gateway.ssh(@host, @user, @opts)
        else
          @session = Net::SSH.start(@host, @user, @opts)
        end
      end

      # @return [Integer] local port number
      def gateway(host, port)
        gateway = Net::SSH::Gateway.new(@host, @user, @opts)
        gateway.open(host, port)
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
        cmd = %w(sudo env -i -)

        cmd.concat(EXPORT_ENVS.merge(env).map { |key, value| "#{key}=\"#{value}\"" })
        cmd.concat(%w(bash --norc --noprofile -x -s))
        logger.debug { "exec: #{cmd}" }
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

      def interactive_session
        Pharos::SSH::InteractiveSession.new(self).run
      end

      def connected?
        @session && !@session.closed?
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
