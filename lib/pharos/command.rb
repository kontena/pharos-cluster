# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    include Pharos::Logging

    option ['-v', '--version'], :flag, "print pharos-cluster version" do
      puts "pharos-cluster #{Pharos::VERSION}"
      exit 0
    end

    option ['-d', '--debug'], :flag, "enable debug output", environment_variable: "DEBUG" do
      debug!
    end


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
