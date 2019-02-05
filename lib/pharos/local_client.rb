# frozen_string_literal: true

require 'monitor'

module Pharos
  class LocalClient
    EXPORT_ENVS = {
      http_proxy: '$http_proxy',
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
        logger.progname = "Local[localhost]"
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
    # @return [Pharos::SSH::Tempfile]
    # @yield [Pharos::SSH::Tempfile]
    def tempfile(prefix: "pharos", content: nil, &block)
      synchronize { Pharos::SSH::Tempfile.new(self, prefix: prefix, content: content, &block) }
    end

    # @param cmd [String] command to execute
    # @param options [Hash]
    # @return [Pharos::Command::Result]
    def exec(cmd, **options)
      synchronize { command(cmd, **options).run }
    end

    # @param cmd [String] command to execute
    # @param options [Hash]
    # @raise [Pharos::ExecError]
    # @return [String] stdout
    def exec!(cmd, **options)
      synchronize { command(cmd, **options).run!.stdout }
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
    # @return [Pathname]
    def file(path)
      Pharos::SSH::RemoteFile.new(self, path)
    end

    def closed?
      false
    end

    def connected?
      true
    end

    def interactive_session
      return unless ENV['SHELL']
      synchronize { system ENV['SHELL'] }
    end

    private

    def command(cmd, **options)
      LocalCommand.new(self, cmd, **options)
    end
  end
end
