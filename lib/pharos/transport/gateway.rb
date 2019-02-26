# frozen_string_literal: true

require 'net/ssh/gateway'
require 'monitor'

module Pharos
  module Transport
    class Gateway
      attr_reader :host, :session

      include MonitorMixin

      def initialize(host)
        super()
        @host = host
      end

      def logger
        @logger ||= Logger.new($stderr).tap do |logger|
          logger.progname = "#{self.class.name}[#{host}]"
          logger.level = ENV["DEBUG_TRANSPORT"] ? Logger::DEBUG : Logger::INFO
        end
      end

      def to_s
        "#{host.user}@#{host.address}:#{host.ssh_port}"
      end

      def connect
        synchronize do
          begin
            non_interactive = true
            logger.debug { "Connecting gateway #{host.user}@#{host.address}:#{host.ssh_port}" }
            @session = Net::SSH::Gateway.new(host.address, host.user, host.ssh_options.merge(non_interactive: non_interactive, port: host.ssh_port))
            logger.debug { "Connected" }
            true
          rescue *Pharos::Transport::SSH::RETRY_CONNECTION_ERRORS
            logger.debug { "Received #{exc.class.name} : #{exc.message} when connecting to #{host.user}@#{host.address}" }
            raise if non_interactive == false || !$stdin.tty? # don't re-retry

            logger.debug { "Retrying in interactive mode.." }
            non_interactive = false
            retry
          end
        end
      end

      # @return [Hash<port[Integer] => address[String]>]
      def ports
        @ports ||= {}
      end

      # @param address [String] target host address
      # @param port [Integer] target port
      # @return [Integer] forwarded port on localhost
      def open(address, port)
        connect unless session

        synchronize do
          local_port = session.open(address, port)
          logger.debug { "Opened tunnel from localhost:#{local_port} to #{address}:#{port}" }
          ports[local_port] = address
          local_port
        end
      end

      # @param host [Pharos::Configuration::Host]
      # @return [Pharos::Transport::SSH]
      def ssh(host)
        connect unless session

        synchronize do
          port = open(host.address, host.ssh_port)
          Pharos::Transport::SSH.new(host, gateway: self, port: port)
        end
      end

      def disconnect(host)
        synchronize do
          ports.select { |_, address| address == host.address }.each do |port, _|
            close(port)
          end
        end

        shutdown! if ports.empty?
      end

      def close(port)
        sychronize do
          address = ports.delete(port)
          logger.debug { "Closing tunnel from localhost:#{port} to #{address}" }
          session&.close(port)
        end

        shutdown! if ports.empty?
      end

      def active?
        synchronize do
          session&.active?
        end
      end

      def shutdown!
        synchronize do
          return if !session

          logger.debug { "Shutting down gateway session" }
          ports.keys.each { |port| close(port) }
          session.shutdown!
          sleep 0.5 until !session.active?
          @session = nil
          logger.debug { "Gateway shutdown complete" }
        end
      end
    end
  end
end
