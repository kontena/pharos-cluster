# frozen_string_literal: true

module Pharos
  class LocalClient < Pharos::Transport
    def connect
      nil
    end

    def closed?
      false
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
      LocalCommand.new(self, cmd, **options)
    end
  end
end
