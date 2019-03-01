# frozen_string_literal: true

require_relative 'kube'

module Pharos
  class PhaseManager
    using Pharos::CoreExt::Colorize
    include Pharos::Logging

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
    def run(phases, &block)
      threads = phases.map { |phase|
        Thread.new do
          Thread.current.report_on_exception = false
          Thread.current.abort_on_exception = true
          Retry.perform(yield_object: phase, logger: logger, exceptions: RETRY_ERRORS, &block)
        end
      }
      threads.map(&:value)
    rescue StandardError
      threads.map(&:kill)
      sleep 0.5 until threads.all?(&:stop?)
      raise
    end

    # @return [Pharos::Phase]
    def prepare_phase(phase_class, host, **options)
      options = @options.merge(options)
      phase_class.new(host, **options)
    end

    def apply(phase_class, hosts, **options)
      phases = hosts.map { |host| prepare_phase(phase_class, host, **options) }

      run(phases) do |phase|
        start = Time.now

        phase.call

        phase.logger.info 'Completed phase in %<duration>.2fs' % { duration: Time.now - start }
      end
    end
  end
end
