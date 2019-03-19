# frozen_string_literal: true

require 'io/console'
require 'io/wait'

module Pharos
  module Transport
    class InteractiveSSH
      attr_reader :client

      # @param client [Pharos::Transport::SSH]
      def initialize(client)
        @client = client
      end

      def run
        $stdin.raw!
        $stdin.echo = false
        $stdin.sync = true
        old_winch_handler = "DEFAULT"

        @client.session.open_channel do |channel|
          old_winch_handler = Signal.trap("SIGWINCH") do
            rows, columns = IO.console.winsize
            channel.send_channel_request "window-change", :long, columns, :long, rows, :long, 0, :long, 0
          end

          @client.session.listen_to($stdin) do |stdin|
            input = stdin.readpartial(1024)
            channel.send_data(input) unless input.empty?
          end

          channel.on_data do |_, data|
            $stdout.write(data)
          end

          channel.on_extended_data do |_, data|
            $stdout.write(data)
          end

          rows, columns = IO.console.winsize
          channel.request_pty term: ENV['TERM'] || 'ascii', chars_wide: columns, chars_high: rows do
            channel.send_channel_request "shell"
          end

          channel.connection.loop do
            channel.active?
          end
        end.wait
      ensure
        Signal.trap("SIGWINCH", old_winch_handler)
        $stdin.cooked!
        $stdin.echo = true
      end
    end
  end
end
