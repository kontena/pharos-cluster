# frozen_string_literal: true

require 'net/ssh'

module Pharos
  module Transport
    class SSH < Base
      attr_reader :session

      def self.class_mutex
        @class_mutex ||= Mutex.new
      end

      def class_mutex
        self.class.class_mutex
      end

      RETRY_CONNECTION_ERRORS = [
        Net::SSH::AuthenticationFailed,
        Net::SSH::Authentication::KeyManagerError,
        Net::SSH::Authentication::ED25519::OpenSSHPrivateKeyLoader::DecryptError
      ].freeze

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
        if bastion
          # wait for bastion host connection, otherwise we might get invalid session_factory
          sleep 0.1 until bastion&.transport && bastion&.transport.connected? && !bastion.transport.disconnecting?
          session_factory = bastion.transport
        else
          session_factory = Net::SSH
        end

        synchronize do
          logger.debug { "connect: #{@user}@#{@host} (#{@opts})" }
          non_interactive = true
          begin
            @session = session_factory.start(@host, @user, @opts.merge(options).merge(non_interactive: non_interactive))
            logger.debug "Connected"
            class_mutex.unlock if class_mutex.locked? && class_mutex.owned?
          rescue *RETRY_CONNECTION_ERRORS => e
            logger.debug "Received #{e.class.name} : #{e.message} when connecting to #{@user}@#{@host}"
            raise if non_interactive == false || !$stdin.tty? # don't re-retry

            logger.debug { "Retrying in interactive mode" }
            non_interactive = false

            sleep 0.1 until class_mutex.try_lock
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

        local_port = next_port

        begin
          synchronize do
            @session.forward.local(local_port, host, port)
            logger.debug "Opened port forward 127.0.0.1:#{local_port} -> #{host}:#{port}"
          end
        rescue Errno::EADDRINUSE
          logger.debug "Port #{local_port} in use, trying next one"
          local_port = next_port
          retry
        end

        ensure_event_loop
        local_port
      rescue IOError
        disconnect
        retry
      end

      # Starts a tunnel and calls Net::SSH.start
      # Will be called only if host is using a bastion
      #
      # @param host [String]
      # @param user [String]
      # @param options [Hash]
      # @return [Net::SSH::Connection::Session]
      def start(host, user, options = {})
        Net::SSH.start('127.0.0.1', user, options.merge(port: forward(host, options[:port] || 22)))
      end

      # Will be called only if transport is used as a bastion for other hosts
      #
      # @param local_port [Integer]
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
        synchronize { Pharos::Transport::InteractiveSSH.new(self).run }
      rescue IOError
        disconnect
      end

      def connected?
        synchronize { @session && !@session.closed? }
      end

      def disconnecting?
        synchronize { @disconnecting == true }
      end

      def disconnect
        @disconnecting = true
        no_active_locals = @session.forward.active_locals.empty?
        until no_active_locals do
          synchronize do
            no_active_locals = @session.forward.active_locals.size == 1
          end
          sleep 0.1
        end
        synchronize do
          bastion&.transport&.close(@session.options[:port]) if bastion
          @session&.forward&.active_locals&.each do |local_port, _host|
            @session&.forward&.cancel_local(local_port)
          end
          @session&.close unless @session&.closed?
        end
      ensure
        @disconnecting = false
      end

      private

      def command(cmd, **options)
        Pharos::Transport::Command::SSH.new(self, cmd, **options)
      end

      def ensure_event_loop
        synchronize do
          @event_loop ||= Thread.new do
            Thread.current.report_on_exception = logger.level == Logger::DEBUG
            logger.debug "Started SSH event loop"
            while @session
              synchronize do
                @session.process(0.1)
              end
              Thread.pass
            end
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
