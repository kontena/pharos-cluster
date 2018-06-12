# frozen_string_literal: true

module Pharos
  class VersionCommand < Pharos::Command
    def execute
      puts "pharos-cluster version #{Pharos::VERSION}"
      manager = ClusterManager.new(Pharos::Config.new({}), pastel: false)
      manager.load
      Pharos::HostConfigManager.load_configs

      puts "3rd party versions:"
      grouped_phases = phases.group_by { |c|
        if c.os_release
          "#{c.os_release.id} #{c.os_release.version}"
        else
          nil
        end
      }
      grouped_phases.each do |os, phases|
        puts "  #{os || 'all host operating systems'}:"
        phases.each do |c|
          puts "    - #{c.name} #{c.version} (#{c.license})"
        end
      end
      puts "Addon versions:"
      addons.each do |c|
        puts "  - #{c.addon_name} #{c.version} (#{c.license})"
      end
    end

    def phases
      Pharos::Phases.components.sort_by(&:name)
    end

    def addons
      Pharos::AddonManager.addons.sort_by(&:name)
    end
  end
end
