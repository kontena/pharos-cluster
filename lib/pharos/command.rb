# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    def pastel
      @pastel ||= Pastel.new
    end
  end
end
