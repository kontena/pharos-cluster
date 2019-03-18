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

      # @param options [Hash] see Net::SSH#start
      # @raise [multiple] when unsuccesful
      # @return [true] when successful
      def connect(**options)
        session_factory = bastion&.transport || Net::SSH

        synchronize do
          logger.debug { "connect: #{@user}@#{@host} (#{@opts})" }
          non_interactive = true
          begin
            @session = session_factory.start(@host, @user, @opts.merge(options).merge(non_interactive: non_interactive))
            logger.debug "Connected"
          rescue *RETRY_CONNECTION_ERRORS => exc
            logger.debug "Received #{exc.class.name} : #{exc.message} when connecting to #{@user}@#{@host}"
            raise if non_interactive == false || !$stdin.tty? # don't re-retry

            logger.debug { "Retrying in interactive mode" }
            non_interactive = false
            retry
          end
        end

        true
      end

      # @param host [String]
      # @param port [Integer]
      # @return [Integer] local port number
      def forward(host, port)
        connect unless connected?

        begin
          local_port = next_port
          @session.forward.local(local_port, host, port)
          logger.debug "Opened port forward 127.0.0.1:#{local_port} -> #{host}:#{port}"
        rescue Errno::EADDRINUSE
          retry
        end

        ensure_event_loop
        local_port
      rescue IOError
        disconnect
        retry
      end

      # Starts a tunnel and calls Net::SSH.start
      # @param host [String]
      # @param user [String]
      # @param options [Hash]
      # @return [Net::SSH::Connection::Session]
      def start(host, user, options = {})
        Net::SSH.start('127.0.0.1', user, options.merge(port: forward(host, options[:port] || 22)))
      end

      def close(local_port)
        return unless connected?

        synchronize do
          @session.forward.cancel_local(local_port)
          logger.debug "Closed port forward on #{local_port}"
        end
      rescue IOError
        disconnect
      end

      def interactive_session
        connect unless connected?

        synchronize { Pharos::Transport::InteractiveSSH.new(self).run }
      rescue IOError
        disconnect
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def disconnect
        synchronize do
          logger.debug { "disconnect SSH #{self}" }
          bastion&.transport&.close(@session.options[:port]) if @session&.host == "127.0.0.1"
          @session&.forward&.active_locals&.each do |local_port, _host|
            @session&.forward&.cancel_local(local_port)
          end
          @session&.close unless @session&.closed?
        end
      end

      def command(cmd, **options)
        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      rescue IOError
        logger.debug "Encountered IOError, retrying"
        disconnect
        retry
      end

      def ensure_event_loop
        synchronize do
          @event_loop ||= Thread.new do
            Thread.current.report_on_exception = logger.level == Logger::DEBUG
            logger.debug "Started SSH event loop"
            @session.loop(0.1) { @session.busy?(true) || !@session.forward.active_locals.empty? }
          rescue IOError, Errno::EBADF => ex
            logger.debug "Received #{ex.class.name} (expected when tunnel has been closed)"
          ensure
            logger.debug "Closed SSH event loop"
            synchronize do
              @event_loop = nil
            end
          end
        end
      end

      def next_port
        synchronize do
          @next_port ||= 65_535
          @next_port -= 1
          @next_port = 65_535 if @next_port <= 1025
          @next_port
        end
      end
    end
  end
end
