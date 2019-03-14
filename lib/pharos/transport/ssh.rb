# frozen_string_literal: true

require 'net/ssh'

module Pharos
  module Transport
    class SSH < Base
      using Pharos::CoreExt::Colorize

      attr_reader :session

      def self.options_for(host)
        {}.tap do |opts|
          opts[:keys] = [host.ssh_key_path] if host.ssh_key_path
          opts[:send_env] = [] # override default to not send LC_* envs
          if host.ssh_proxy_command && !host.bastion
            opts[:proxy] = Net::SSH::Proxy::Command.new(host.ssh_proxy_command)
          elsif host.bastion
            opts[:proxy] = Pharos::Transport.gateway(host.bastion.host)
          end
          opts[:port] = host.ssh_port
        end
      end

      RETRY_CONNECTION_ERRORS = [
        Net::SSH::AuthenticationFailed,
        Net::SSH::Authentication::KeyManagerError
      ].freeze

      # @param host [Pharos::Configuration::Host]
      # @param gateway [Pharos::Transport::Gateway]
      # @param port [Integer] ssh port
      # @param opts [Hash]
      def initialize(host)
        super(host)
      end

      # @return [String]
      def to_s
        "SSH #{host.user}@#{host.address}:#{host.ssh_port}#{via.dim}"
      end

      # @return [String]
      def via
        if host.bastion
          " via SSH tunnel #{host.bastion.host}:#{host.bastion.host.ssh_port}#{'<ssh_proxy_command>' if host.bastion.host.ssh_proxy_command}"
        elsif host.ssh_proxy_command
          " via ssh_proxy_command "
        else
          ""
        end
      end

      # @raise [multiple] when unsuccesful
      # @return [Pharos::Transport::SSH] when successful
      def connect
        synchronize do
          non_interactive = true
          begin
            logger.debug { "connect #{self}" }
            @session = Net::SSH.start(host.address, host.user, self.class.options_for(host).merge(non_interactive: non_interactive))
            logger.debug { "connected #{self}" }
            self
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
          logger.debug { "disconnect SSH #{self}" }
          @session.close if connected?
          @session = nil
        end
      end

      def command(cmd, **options)
        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      rescue IOError
        logger.debug "Encountered IOError, retrying"
        disconnect
        retry
      end
    end
  end
end
