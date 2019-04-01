# frozen_string_literal: true

require 'monitor'

module Pharos
  module Transport
    class Base
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

      include MonitorMixin

      attr_reader :host

      # @param host [String]
      # @param opts [Hash]
      def initialize(host, **opts)
        super()
        @host = host
        @opts = opts
      end

      def logger
        @logger ||= Logger.new($stderr).tap do |logger|
          logger.progname = "#{self.class.name}[#{host}]"
          logger.level = ENV["DEBUG_TRANSPORT"] ? Logger::DEBUG : Logger::INFO
        end
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
      # @return [Pharos::Transport::Tempfile]
      # @yield [Pharos::Transport::Tempfile]
      def tempfile(prefix: "pharos", content: nil, &block)
        synchronize { Pharos::Transport::Tempfile.new(self, prefix: prefix, content: content, &block) }
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @return [Pharos::Command::Result]
      def exec(cmd, **options)
        cmd = host.environment.map { |key, value| "#{key}=#{value.shellescape}" }.join(' ') + " " + cmd
        synchronize { command(cmd, **options).run }
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @raise [Pharos::ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        cmd = host.environment.map { |key, value| "#{key}=#{value.shellescape}" }.join(' ') + " " + cmd
        synchronize { command(cmd, **options).run!.stdout }
      end

      # @param name [String] name of script
      # @param env [Hash] environment variables hash
      # @param path [String] real path to file, defaults to script
      # @raise [Pharos::ExecError]
      # @return [String] stdout
      def exec_script!(name, env: {}, path: nil, **options)
        script = ::File.read(path || name)
        cmd = %w(sudo env -i -)

        cmd.concat(EXPORT_ENVS.merge(env).map { |key, value| "#{key}=#{host.environment.fetch(key, value).shellescape}" })
        cmd.concat(%w(bash --norc --noprofile -x -s))
        synchronize { command(cmd, stdin: script, source: name, **options).run!.stdout }
      end

      # @param cmd [String] command to execute
      # @param options [Hash]
      # @return [Boolean]
      def exec?(cmd, **options)
        exec(cmd, **options).success?
      end

      # @param path [String]
      # @return [Pathname]
      def file(path)
        Pharos::Transport::TransportFile.new(self, path)
      end

      def closed?
        connected?
      end

      def connected?
        abstract_method!
      end

      def connect
        abstract_method!
      end

      def command
        abstract_method!
      end

      def disconnect
        abstract_method!
      end

      def interactive_session
        abstract_method!
      end

      private

      def abstract_method!
        raise NotImplementedError, 'This is an abstract base method. Implement in your subclass.'
      end
    end
  end
end
