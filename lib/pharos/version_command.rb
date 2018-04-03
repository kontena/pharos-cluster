# frozen_string_literal: true

module Pharos
  class VersionCommand < Pharos::Command
    option "--all", :flag, "Show all versions"

    def execute
      puts "kupo version #{Pharos::VERSION}"
      report_all if all?
    end

    def report_all
      load_phases
      puts "3rd party versions:"
      Pharos::Phases.components.each do |c|
        puts "  - #{c.name}=#{c.version} (#{c.license})"
      end
      puts "Addon versions:"
      Pharos::AddonManager.new([__dir__ + '/addons']).addon_classes.each do |c|
        puts "  - #{c.name}=#{c.version} (#{c.license})"
      end
    end

    def load_phases
      Dir.glob(__dir__ + '/phases/*.rb').each { |f| require(f) }
    end
  end
end
