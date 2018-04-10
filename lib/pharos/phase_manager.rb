# frozen_string_literal: true

module Pharos
  class PhaseManager
    include Pharos::Logging

    # @param dirs [Array<String>]
    def initialize(dirs, ssh_manager: , **options)
      @ssh_manager = ssh_manager
      @options = options

      load_phases(dirs)
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_parallel(phases)
      threads = phases.map { |phase|
        Thread.new do
          begin
            yield phase
          rescue => exc
            puts " [#{phase}] #{exc.class}: #{exc.message}"
            raise
          end
        end
      }
      threads.map { |thread| thread.value }
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_serial(phases)
      phases.map do |phase|
        yield phase
      end
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @param parallel [Boolean]
    # @return [Array<...>]
    def run(phases, parallel: true, &block)
      if parallel
        run_parallel(phases, &block)
      else
        run_serial(phases, &block)
      end
    end

    def apply(phase_class, hosts, ssh: false, parallel: false, **options)
      options = @options.merge(options)

      phases = hosts.map { |host|
        # one thread per node, one ssh client per node => one thread per ssh client
        ssh = ssh ? @ssh_manager.client_for(host) : nil

        phase_class.new(host,
          ssh: ssh,
          **options
        )
      }

      run(phases, parallel: parallel) do |phase|
        phase.call
      end
    end

    # @param dirs [Array<String>]
    def load_phases(dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end
  end
end
