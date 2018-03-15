# frozen_string_literal: true

module Kupo
  class VersionCommand < Kupo::Command
    option '--all', :flag, 'Show all versions'

    def execute
      puts "kupo version #{Kupo::VERSION}"
      if all?
        load_phases
        puts '3rd party versions:'
        Kupo::Phases::Base.components.each do |c|
          puts "  - #{c.name}=#{c.version} (#{c.license})"
        end
        puts 'Addon versions:'
        Kupo::AddonManager.new([__dir__ + '/addons']).addon_classes.each do |c|
          puts "  - #{c.name}=#{c.version} (#{c.license})"
        end
      end
    end

    def load_phases
      Dir.glob(__dir__ + '/phases/*.rb').each { |f| require(f) }
    end
  end
end
