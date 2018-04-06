# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    include Pharos::Logging

    def run(*args)
      super
    rescue StandardError => ex
      raise if ex.class.to_s["Clamp::"] || debug?
      abort "ERROR: #{ex.message} (#{ex.class})"
    end

    def pastel
      @pastel ||= Pastel.new
    end
  end
end
