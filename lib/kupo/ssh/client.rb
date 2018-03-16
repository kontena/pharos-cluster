require 'net/ssh'
require 'net/scp'

module Kupo::SSH
  class Error < StandardError

  end
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

  class Client
    # @param host [Kupo::Configuration::Host]
    def self.for_host(host)
      @connections ||= {}
      unless @connections[host]
        @connections[host] = new(host.address, host.user, {
          keys: [host.ssh_key_path]
        })
        @connections[host].connect
      end

      @connections[host]
    end

    def self.disconnect_all
      return unless @connections

      @connections.each do |host, connection|
        connection.disconnect
      end
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
      logger.debug { "Connect #{@user}@#{@host} (#{@opts})" }
      @session = Net::SSH.start(@host, @user, @opts)
    end

    # @param cmd [String] command to execute
    # @return [Integer] exit status
    def exec(cmd)
      require_session!
      exit_status = 0
      ssh_channel = @session.open_channel do |channel|
        logger.debug "exec: #{cmd}"
        channel.exec cmd do |ech, success|
          raise Error, "Failed to exec #{cmd}" unless success

          ech.on_data do |_, data|
            logger.debug { "exec stdout:\n#{data}" }

            yield(:stdout, data) if block_given?
          end
          ech.on_extended_data do |c, type, data|
            logger.debug { "exec stderr: #{data}" }

            yield(:stderr, data) if block_given?
          end
          ech.on_request("exit-status") do |_, data|
            exit_status = data.read_long

            logger.debug { "exec exit-status: #{exit_status}" }
          end
        end
      end
      ssh_channel.wait

      exit_status
    end

    # @param cmd [String] command to execute
    # @raise [ExecError]
    def exec!(cmd, &block)
      output = ''

      exit_status = exec(cmd) do |type, data|
        output += data

        yield type, data if block_given?
      end

      unless exit_status.zero?
        raise ExecError.new(cmd, exit_status, output)
      end
    end

    # @param cmd [String] command to execute
    # @return [Boolean]
    def exec?(cmd, &block)
      exec(cmd, &block).zero?
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
      local = StringIO.new

      download(path, local)

      local.string
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
