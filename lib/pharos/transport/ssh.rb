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

      def connect
        synchronize do
          if host.bastion
            logger.debug { "connect #{host.user}@#{host.address} (#{host.ssh_options}) via bastion: #{host.bastion.user}@#{host.bastion.address} (#{host.bastion.host.ssh_options})" }
            @gateway = host.bastion.gateway
            @session = @gateway.ssh(host.address, host.user, host.ssh_options)
          else
            non_interactive = true
            begin
              logger.debug { "connect #{host.user}@#{host.address} (#{host.ssh_options})" }
              @session = Net::SSH.start(host.address, host.user, host.ssh_options.merge(non_interactive: non_interactive))
            rescue *RETRY_CONNECTION_ERRORS => exc
              logger.debug { "Received #{exc.class.name} : #{exc.message} when connecting to #{host.user}@#{host.address}" }
              raise if non_interactive == false || !$stdin.tty? # don't re-retry

              logger.debug { "Retrying in interactive mode" }
              non_interactive = false
              retry
            end
          end
        end
      end

      def interactive_session
        synchronize { Pharos::Transport::InteractiveSSH.new(self).run }
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def disconnect
        return unless connected?

        synchronize do
          logger.debug { "disconnect SSH #{host.user}@#{host.address}" }
          @session.close
          if @gateway
            logger.debug { "disconnect SSH gateway #{host.bastion.user}@#{host.bastion.address}" }
            @gateway.shutdown!
            sleep 0.5 until !@gateway.active?
            @gateway = nil
          end
          @session = nil
        end
      end

      def command(cmd, **options)
        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      end
    end
  end
end
