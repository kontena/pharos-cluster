# frozen_string_literal: true

module Pharos
  module Transport
    class Local < Base
      def forward(*_args)
        raise TypeError, "Non-SSH connections do not provide port forwarding"
      end

      def close(*_args)
        raise TypeError, "Non-SSH connections do not provide port forwarding"
      end

      def connect(**_options)
        nil
      end

      def disconnect
        nil
      end

      def connected?
        true
      end

      def interactive_session
        return unless ENV['SHELL']

        synchronize { system ENV['SHELL'] }
      end

      private

      def command(cmd, timeout: 900, **options)
        Pharos::Transport::Command::Local.new(self, cmd, timeout: timeout, **options)
      end
    end
  end
end
