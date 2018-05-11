# frozen_string_literal: true

module Pharos
  class PhaseManager
    include Pharos::Logging

    # @param dirs [Array<String>]
    def self.load_phases(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end

    # @param config [Pharos::Config]
    # @param ssh_manager [Pharos::SSH::Manager]
    # @param kube_session [Pharos::Kube::Session]
    def initialize(config, ssh_manager:, kube_session:, cluster_context:)
      @config = config
      @ssh_manager = ssh_manager
      @cluster_context = cluster_context
      @kube_session = kube_session
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_parallel(phases)
      threads = phases.map { |phase|
        Thread.new do
          begin
            yield phase
          rescue StandardError => exc
            puts " [#{phase}] #{exc.class}: #{exc.message}"
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
    def prepare_phase(phase_class, host, ssh: false, kube: false, **options)
      fail "kube (#{kube}) is not yet configured for phase: #{phase_class}" if kube && !@kube_session.configured?

      options[:config] = @config
      options[:ssh] = @ssh_manager.client_for(host) if ssh
      options[:kube] = @kube_session if kube

      phase_class.new(host, **options)
    end

    def apply(phase_class, hosts, parallel: false, kube: false, **options)
      fail "kube is not threadsafe for parallel phases: #{phase_class}" if kube && parallel

      phases = hosts.map { |host| prepare_phase(phase_class, host, kube: kube, **options) }

      run(phases, parallel: parallel) do |phase|
        start = Time.now

        phase.call

        logger.debug { "Completed #{phase} in #{'%.3fs' % [Time.now - start]}" }
      end
    end
  end
end
