# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'

module Kupo::SSH
  class Client
    class Error < StandardError
    end

    # @param host [Kupo::Configuration::Host]
    def self.for_host(host)
      @connections ||= {}
      unless @connections[host]
        @connections[host] = new(host.address, host.user,
                                 keys: [host.ssh_key_path])
        @connections[host].connect
      end

      @connections[host]
    end

    def self.disconnect_all
      return unless @connections

      @connections.each do |_host, connection|
        connection.disconnect
      end
    end

    def initialize(host, user = nil, opts = {})
      @host = host
      @user = user
      @opts = opts
    end

    def connect
      @session = Net::SSH.start(@host, @user, @opts)
    end

    # @param cmd [String] command to execute
    # @return [Int] exit code
    def exec(cmd)
      require_session!
      exit_code = 0
      ssh_channel = @session.open_channel do |channel|
        channel.exec cmd do |ech, _success|
          ech.on_data do |_, data|
            yield(:stdout, data) if block_given?
          end
          ech.on_extended_data do |_c, _type, data|
            yield(:stderr, data) if block_given?
          end
          ech.on_request("exit-status") do |_, data|
            exit_code = data.read_long
          end
        end
      end
      ssh_channel.wait

      exit_code
    end

    # @param local_path [String]
    # @param remote_path [String]
    # @param opts [Hash]
    def upload(local_path, remote_path, opts = {})
      require_session!
      @session.scp.upload!(local_path, remote_path, opts)
    end

    # @param remote_path [String]
    # @param local_path [String]
    # @param opts [Hash]
    def download(remote_path, local_path, opts = {})
      require_session!
      @session.scp.download!(remote_path, local_path, opts)
    end

    # @param path [String]
    # @return [Boolean]
    def file_exists?(path)
      exec("[ -e #{path} ]") == 0
    end

    # @param path [String]
    # @return [String,NilClass]
    def file_contents(path)
      dropin = ''
      code = exec("sudo cat #{path}") do |type, data|
        dropin << data if type == :stdout
      end
      if code == 0
        dropin
      end
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
