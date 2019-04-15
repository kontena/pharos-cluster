# frozen_string_literal: true

require_relative 'kube'

module Pharos
  class PhaseManager
    include Pharos::Logging

    class Error < Pharos::Error
      def initialize(errors)
        @errors = errors
      end

      def to_s
        "Phase failed on #{@errors.size} host#{'s' if @errors.size > 1}:\n#{YAML.dump(@errors).delete_prefix("---\n")}"
      end
    end

    RETRY_ERRORS = [
      OpenSSL::SSL::SSLError,
      Excon::Error,
      K8s::Error,
      Pharos::ExecError,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED
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
      threads = phases.map do |phase|
        Thread.new do
          Thread.current.report_on_exception = false
          Thread.current[:host] = phase.host.to_s
          Retry.perform(yield_object: phase, logger: phase.logger, exceptions: RETRY_ERRORS, &block)
        end
      end

      sleep 0.1 until threads.none?(&:alive?)

      # Thread status is false when terminated normally, nil when it terminated with exception
      # rubocop:disable Lint/RescueException
      errors = threads.select { |t| t.status.nil? }.map do |thread|
        thread.value # raises the exception
      rescue Exception => ex
        { thread[:host] => { ex.class.name => ex.message } }
      end
      # rubocop:enable Lint/RescueException

      raise Error, errors unless errors.empty?

      threads.map(&:value)
    end

    # @param phases [Array<Pharos::Phases::Base>]
    # @return [Array<...>]
    def run_serial(phases, &block)
      phases.map do |phase|
        Retry.perform(yield_object: phase, logger: phase.logger, exceptions: RETRY_ERRORS, &block)
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

        phase.logger.info 'Completed phase in %<duration>.2fs' % { duration: Time.now - start }
      end
    end
  end
end
