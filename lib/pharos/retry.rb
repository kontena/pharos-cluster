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
        raise exc if Time.now - start_time > seconds

        if logger
          logger.error { "got error (#{exc.class.name}): #{exc.message.strip}" }
          logger.debug { exc.backtrace.join("\n") }
          logger.error { "retrying after #{wait} seconds ..." }
        end
        sleep wait
        retry_count += 1
        retry
      rescue StandardError => exc
        if logger
          logger.debug { "got error (#{exc.class.name}): #{exc.message.strip}" }
          logger.debug { exc.backtrace.join("\n") }
        end
        raise exc
      end
    end
  end
end
