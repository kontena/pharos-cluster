# frozen_string_literal: true

module Pharos
  module Transport
    class Local < Base
      def to_s
        "LOCAL #{ENV['USER']}@localhost"
      end

      def session
        nil
      end

      def connect
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

      def command(cmd, **options)
        Pharos::Transport::Command::Local.new(self, cmd, **options)
      end
    end
  end
end
