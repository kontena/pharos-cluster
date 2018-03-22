# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'shellwords'

module Kupo
  module SSH
    Error = Class.new(StandardError)

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

      # @param cmd [String] command to execute
      # @return [Exec]
      def exec(cmd, **options)
        require_session!
        Exec.new(self, cmd, **options).run
      end

      # @param cmd [String] command to execute
      # @raise [ExecError]
      # @return [String] stdout
      def exec!(cmd, **options)
        require_session!
        Exec.new(self, cmd, **options).run!.stdout
      end

      # @param script [String] name of script
      # @param path [String] real path to file, defaults to script
      # @raise [ExecError]
      # @return [String] stdout
      def exec_script!(name, env: {}, path: nil, **options)
        script = File.read(path || name)
        cmd = []

        env.each_pair do |e, value|
          cmd << "#{e}=#{Shellwords.escape(value)}"
        end

        cmd.concat(%w(sh -x))

        exec!(cmd.join(' '), stdin: script, debug_source: name, **options)
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
        tmp_path = File.join('/tmp', prefix + '.' + SecureRandom.hex(16))

        upload(StringIO.new(contents), tmp_path)

        exec!("sudo mv #{tmp_path} #{path} || rm #{tmp_path}")
      end

      # @param contents [String]
      # @yield [path]
      # @yieldparam path [String] /tmp/...
      def with_tmpfile(contents, prefix: "kupo")
        path = File.join('/tmp', prefix + '.' + SecureRandom.hex(16))

        upload(StringIO.new(contents), path)

        yield path
      ensure
        exec("rm #{path}") if path
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
