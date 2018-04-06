# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    option '--[no-]color', :flag, "Colorize output", default: $stdout.tty?

    def pastel
      @pastel ||= Pastel.new(enabled: color?)
    end
  end
end
