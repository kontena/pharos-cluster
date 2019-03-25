# frozen_string_literal: true

module Pharos
  module Retry
    DEFAULT_RETRY_ERRORS = [
      OpenSSL::SSL::SSLError,
      Excon::Error,
      K8s::Error
    ].freeze

    # @param seconds [Integer] seconds for how long the block will be retried
    # @param yield_object [Object] object to yield into block
    # @param wait [Integer] duration to wait between retries
    # @param logger [Logger] logger for errors
    # @param exceptions [Array<Exception>] an array of exceptions to rescue from
    def self.perform(seconds = 600, yield_object: nil, wait: 2, logger: nil, exceptions: nil)
      start_time = Time.now
      retry_count = 0
      begin
        yield yield_object
      rescue *(exceptions || DEFAULT_RETRY_ERRORS) => exc
        if Time.now - start_time > seconds
          logger&.error "Retry time limit exceeded"
          raise
        end

        retry_count += 1

        if logger
          logger.warn "Retried 5 times, increasing verbosity" if retry_count == 5
          logger.send(retry_count >= 5 ? :error : :debug, exc)
          logger.warn { "Retrying after #{wait} second#{'s' if wait > 1} (##{retry_count}) ..." }
        end

        sleep wait
        retry
      rescue StandardError => exc
        logger&.debug "Unretriable exception, reraising"
        logger&.debug exc
        raise
      end
    end
  end
end
