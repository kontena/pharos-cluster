# frozen_string_literal: true

require 'shellwords'
require 'monitor'

module Pharos
  class LocalClient
    Error = Class.new(StandardError)

    EXPORT_ENVS = {
      http_proxy: '$http_proxy',
      HTTP_PROXY: '$HTTP_PROXY',
      HTTPS_PROXY: '$HTTPS_PROXY',
      NO_PROXY: '$NO_PROXY',
      FTP_PROXY: '$FTP_PROXY',
      PATH: '$PATH'
    }.freeze

    include MonitorMixin

    attr_reader :session, :host

    # @param opts [Hash]
    def initialize(opts = {})
      super()
      @opts = opts
    end

    def logger
      @logger ||= Logger.new($stderr).tap do |logger|
        logger.progname = "Local[#{localhost}]"
        logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
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
    def tempfile(prefix: "pharos", content: nil)
      ::Tempfile.new(prefix) do |tmpfile|
        tmpfile.write(content) if content
        tmpfile.rewind
        yield tmpfile
      end
    end

    # @param cmd [String] command to execute
    # @param options [Hash]
    # @return [Pharos::Command::Result]
    def exec(cmd, **options)
      synchronize { LocalCommand.new(self, cmd, **options).run }
    end

    # @param cmd [String] command to execute
    # @param options [Hash]
    # @raise [Pharos::SSH::RemoteCommand::ExecError]
    # @return [String] stdout
    def exec!(cmd, **options)
      synchronize { LocalCommand.new(self, cmd, **options).run!.stdout }
    end

    # @param name [String] name of script
    # @param env [Hash] environment variables hash
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
    # @param options [Hash]
    # @return [Boolean]
    def exec?(cmd, **options)
      exec(cmd, **options).success?
    end

    # @param path [String]
    # @return [Pathname]
    def file(path)
      Pharos::LocalFile.new(path)
    end

    def closed?
      false
    end

    def connected?
      true
    end
  end
end
