# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/gateway'
require 'shellwords'
require 'monitor'

module Pharos
  module SSH
    Error = Class.new(StandardError)

    EXPORT_ENVS = {
      http_proxy: '$http_proxy',
      HTTP_PROXY: '$HTTP_PROXY',
      HTTPS_PROXY: '$HTTPS_PROXY',
      NO_PROXY: '$NO_PROXY',
      FTP_PROXY: '$FTP_PROXY',
      PATH: '$PATH'
    }.freeze

    class Client
      include MonitorMixin

      attr_reader :session, :host

      # @param host [String]
      # @param user [String, NilClass]
      # @param opts [Hash]
      def initialize(host, user = nil, opts = {})
        super()
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

      # @return [Hash,NilClass]
      def bastion
        @bastion ||= @opts.delete(:bastion)
      end

      # @param options [Hash] see Net::SSH#start
      def connect(**options)
        synchronize do
          logger.debug { "connect: #{@user}@#{@host} (#{@opts})" }
          if bastion
            gw_opts = {}
            gw_opts[:keys] = [bastion.ssh_key_path] if bastion.ssh_key_path
            gateway = Net::SSH::Gateway.new(bastion.address, bastion.user, gw_opts)
            @session = gateway.ssh(@host, @user, @opts.merge(options))
          else
            @session = Net::SSH.start(@host, @user, @opts.merge(options))
          end
        end
      end

      # @param host [String]
      # @param port [Integer]
      # @return [Integer] local port number
      def gateway(host, port)
        Net::SSH::Gateway.new(@host, @user, @opts).open(host, port)
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
        synchronize { Tempfile.new(self, prefix: prefix, content: content, &block) }
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @return [Pharos::Command::Result]
      def exec(cmd, **options)
        require_session!
        synchronize { RemoteCommand.new(self, cmd, **options).run }
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @raise [Pharos::ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        require_session!
        synchronize { RemoteCommand.new(self, cmd, **options).run!.stdout }
      end

      # @param name [String] name of script
      # @param env [Hash] environment variables hash
      # @param path [String] real path to file, defaults to script
      # @raise [Pharos::ExecError]
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
      # @param options [Hash]
      # @return [Boolean]
      def exec?(cmd, **options)
        exec(cmd, **options).success?
      end

      # @param path [String]
      # @return [Pharos::SSH::RemoteFile]
      def file(path)
        Pharos::SSH::RemoteFile.new(self, path)
      end

      def interactive_session
        synchronize { Pharos::SSH::InteractiveSession.new(self).run }
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def closed?
        !connected?
      end

      def disconnect
        synchronize { @session.close if @session && !@session.closed? }
      end

      private

      def require_session!
        raise Error, "Connection not established" if @session.nil? || @session.closed?
      end
    end
  end
end
