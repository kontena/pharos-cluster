require 'net/ssh'
require 'net/scp'

module Shokunin::SSH

  class Client

    class Error < StandardError
    end

    # @param host [Shokunin::Configuration::Host]
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

    def connect
      @session = Net::SSH.start(@host, @user, @opts)
    end

    # @param cmd [String] command to execute
    # @return [Int] exit code
    def exec(cmd)
      require_session!
      exit_code = 0
      ssh_channel = @session.open_channel do |channel|
        channel.exec cmd do |ech, success|
          ech.on_data do |_, data|
            #print data if output
            yield(:stdout, data) if block_given?
          end
          ech.on_extended_data do |c, type, data|
            #$stderr.print data if output
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
    def upload(local_path, remote_path, opts = {})
      require_session!
      @session.scp.upload!(local_path, remote_path, opts)
    end

    def download(remote_path, local_path, opts = {})
      require_session!
      @session.scp.download!(remote_path, local_path, opts)
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