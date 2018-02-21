require 'net/ssh'
require 'net/scp'

module Kuntena::SSH

  class Client

    class Error < StandardError
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