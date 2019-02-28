# frozen_string_literal: true

module Pharos
  class VersionCommand < Pharos::Command
    def execute
      puts "Kontena Pharos:"
      puts "  - #{File.basename($PROGRAM_NAME)} version #{Pharos.version}"
      ClusterManager.new(Pharos::Config.new({})).load

      phases.each do |os, phases|
        title = (os || 'Common').capitalize
        puts "#{title}:"
        phases.each do |c|
          puts "  - #{c.name} #{c.version} (#{c.license})"
        end
      end
      puts "Add-ons:"
      addons.each do |c|
        puts "  - #{c.addon_name} #{c.version} (#{c.license})"
      end
    end

    # @return [Array<Pharos::Phases::Component>]
    def phases
      phases = Pharos::Phases.components.sort_by(&:name)
      phases.group_by { |c|
        if c.os_release
          "#{c.os_release.id} #{c.os_release.version}"
        end
      }
    end

    # @return [Array<Pharos::Addon>]
    def addons
      Pharos::AddonManager.addons.sort_by(&:name)
    end
  end
end
