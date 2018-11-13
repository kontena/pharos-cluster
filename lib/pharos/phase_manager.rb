# frozen_string_literal: true

require_relative 'kube'

module Pharos
  class PhaseManager
    include Pharos::Logging

    RETRY_ERRORS = [
      OpenSSL::SSL::SSLError,
      Excon::Error,
      K8s::Error,
      Pharos::SSH::RemoteCommand::ExecError
    ].freeze

    # @param dirs [Array<String>]
    def self.load_phases(*dirs)
      dirs.each do |dir|
        Dir.glob(File.join(dir, '*.rb')).each { |f| require(f) }
      end
    end

    # @param dirs [Array<String>]
    def initialize(**options)
      @options = options
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_parallel(phases, &block)
      threads = phases.map { |phase|
        Thread.new do
          yield_phase_with_retry(phase, &block)
        end
      }
      threads.map(&:value)
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_serial(phases, &block)
      phases.map do |phase|
        yield_phase_with_retry(phase, &block)
      end
    end

    # @param phase [Pharos::Phases::Base]
    # @param retry_times [Integer]
    def yield_phase_with_retry(phase, retry_times = 10)
      retries = 0
      begin
        yield phase
      rescue *RETRY_ERRORS => exc
        raise if retries >= retry_times

        logger.error { "[#{phase.host}] got error (#{exc.class.name}): #{exc.message.strip}" }
        logger.debug { exc.backtrace.join("\n") }
        logger.error { "[#{phase.host}] retrying after #{2**retries} seconds ..." }
        sleep 2**retries
        retries += 1
        retry
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
    def prepare_phase(phase_class, host, **options)
      options = @options.merge(options)
      phase_class.new(host, **options)
    end

    def apply(phase_class, hosts, parallel: false, **options)
      phases = hosts.map { |host| prepare_phase(phase_class, host, **options) }

      run(phases, parallel: parallel) do |phase|
        start = Time.now

        phase.call

        logger.debug { "Completed #{phase} in #{'%.3fs' % [Time.now - start]}" }
      end
    end
  end
end
