module Shokunin
  class VersionCommand < Shokunin::Command

    option "--all", :flag, "Show all versions"

    def execute
      puts "Shokunin version #{Shokunin::VERSION}"
      if all?
        load_phases
        puts "3rd party versions:"
        Shokunin::Phases::Base.components.each do |c|
          puts "  - #{c.name}=#{c.version} (#{c.license})"
        end
      end
    end

    def load_phases
      Dir.glob(__dir__ + '/phases/*.rb').each { |f| require(f) }
    end
  end
end