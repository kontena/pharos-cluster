# frozen_string_literal: true

require 'net/ssh'

module Pharos
  module Transport
    class SSH < Base
      attr_reader :session

      RETRY_CONNECTION_ERRORS = [
        Net::SSH::AuthenticationFailed,
        Net::SSH::Authentication::KeyManagerError,
        ArgumentError # until the ED25519 passphrase is fixed
      ].freeze

      # @param host [Pharos::Configuration::Host]
      # @param gateway [Pharos::Transport::Gateway]
      # @param port [Integer] ssh port
      # @param opts [Hash]
      def initialize(host, gateway: nil, port: nil)
        super(host)
        @gateway = gateway
        @port = port || host.ssh_port
      end

      def to_s
        "SSH #{host.user}@#{host.address}:#{host.ssh_port}#{" using proxy command" if host.ssh_proxy_command}#{" via #{@gateway}->127.0.0.1:#{@port} " if @gateway}"
      end

      def connect
        synchronize do
          connect_address = @gateway ? '127.0.0.1' : host.address

          non_interactive = true
          begin
            logger.debug { "connect #{self}" }
            @session = Net::SSH.start(connect_address, host.user, host.ssh_options.merge(non_interactive: non_interactive, port: @port))
            logger.debug { "connected" }
            true
          rescue *RETRY_CONNECTION_ERRORS => exc
            logger.debug { "Received #{exc.class.name} : #{exc.message} when connecting to #{self}" }
            raise if non_interactive == false || !$stdin.tty? # don't re-retry

            logger.debug { "Retrying in interactive mode" }
            non_interactive = false
            retry
          end
        end
      end

      def interactive_session
        connect unless connected?

        synchronize { Pharos::Transport::InteractiveSSH.new(self).run }
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def disconnect
        synchronize do
          logger.debug { "disconnect SSH #{host.user}@#{host.address}" }
          @session.close if connected?
          if @gateway
            logger.debug { "disconnect SSH gateway" }
            @gateway.close(@port)
          end
          @session = nil
        end
      end

      def command(cmd, **options)
        connect unless connected?

        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      end
    end
  end
end
