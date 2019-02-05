# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/gateway'

module Pharos
  module Transport
    class SSH < Base
      attr_reader :session

      # @param host [String]
      # @param opts [Hash]
      def initialize(host, **opts)
        super(host, opts)
        @user = @opts.delete(:user)
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

      def interactive_session
        synchronize { Pharos::Transport::InteractiveSSH.new(self).run }
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def disconnect
        synchronize { @session.close if @session && !@session.closed? }
      end

      private

      def command(cmd, **options)
        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      end
    end
  end
end
