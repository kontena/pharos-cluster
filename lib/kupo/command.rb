# frozen_string_literal: true

module Kupo
  class Command < Clamp::Command
    def pastel
      @pastel ||= Pastel.new
    end
  end
end
