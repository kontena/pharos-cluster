# frozen_string_literal: true

module Pharos
  class PhaseManager
    # @param dirs [Array<String>]
    def self.load_phases(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end

    # @param dirs [Array<String>]
    def initialize(ssh_manager:, **options)
      @ssh_manager = ssh_manager
      @options = options
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_parallel(phases)
      threads = phases.map { |phase|
        Thread.new do
          begin
            yield phase
          rescue StandardError => exc
            Out.error(phase.to_s) { "#{exc.class}: #{exc.message}" }
            raise
          end
        end
      }
      threads.map(&:value)
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

    # @return [Pharos::Phase]
    def prepare_phase(phase_class, host, ssh: false, **options)
      options = @options.merge(options)

      options[:ssh] = @ssh_manager.client_for(host) if ssh

      phase_class.new(host, **options)
    end

    def apply(phase_class, hosts, parallel: false, **options)
      phases = hosts.map { |host| prepare_phase(phase_class, host, **options) }

      run(phases, parallel: parallel) do |phase|
        start = Time.now

        phase.call

        Out.debug { "Completed #{phase} in #{'%.3fs' % [Time.now - start]}" }
      end
    end
  end
end
