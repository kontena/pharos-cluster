# frozen_string_literal: true

module Pharos
  class VersionCommand < Pharos::Command
    def execute
      puts "pharos-cluster version #{Pharos::VERSION}"
      load_phases
      load_addons
      puts "3rd party versions:"
      phases.each do |c|
        puts "  - #{c.name}=#{c.version} (#{c.license})"
      end
      puts "Addon versions:"
      addons.each do |c|
        puts "  - #{c.name}=#{c.version} (#{c.license})"
      end
    end
    def phases
      Pharos::Phases.components.sort_by(&:name)
    end

    def addons
      Pharos::AddonManager.addon_classes.sort_by(&:name)
    end

    def load_phases
      Pharos::PhaseManager.load_phases(__dir__ + '/phases')
    end

    def load_addons
      Pharos::AddonManager.load_addons
    end
  end
end
