# frozen_string_literal: true

module Pharos
  class VersionCommand < Pharos::Command
    option %w(-a --all), :flag, "include ruby and rubygems versions"

    def execute
      puts "Kontena Pharos:"
      puts "  - #{File.basename($PROGRAM_NAME)} version #{Pharos.version}"

      if all?
        puts "Ruby:"
        puts "  - #{RUBY_DESCRIPTION} (Ruby, GPLv2, 2-clause BSD)"
        puts "Rubygems:"
        Gem.loaded_specs.map { |name, spec| "  - #{name} #{spec.version} (#{spec.licenses.join(', ')})" }.sort.each { |g| puts g }
      end

      ClusterManager.new(Pharos::Config.new({})).load

      phases.each do |os, phases|
        title = (os || 'Common').capitalize
        puts "#{title}:"
        phases.each do |c|
          puts "  - #{c.name} #{c.version} (#{c.license})"
        end
      end
      puts "Add-ons:"
      addons.each do |name, c|
        puts "  - #{name} #{c.version} (#{c.license})"
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
      Pharos::AddonManager.addons.sort_by { |name, _klass| name }
    end
  end
end
