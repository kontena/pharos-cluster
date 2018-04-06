# frozen_string_literal: true

module Pharos
  class Command < Clamp::Command
    option ['-v', '--version'], :flag, "print pharos-cluster version" do
      puts "pharos-cluster #{Pharos::VERSION}"
      exit 0
    end

    option ['-d', '--debug'], :flag, "enable debug output", environment_variable: "DEBUG" do
      ENV["DEBUG"] = "true"
    end

    def pastel
      @pastel ||= Pastel.new
    end
  end
end
