# frozen_string_literal: true

require 'logger'

module Pharos
  module Debug
    def self.module
      ENV['DEBUG'].to_s.empty? ? Disabled : Enabled
    end

    module Disabled
      LOG_LEVEL = Logger::INFO

      def debug?
        false
      end
      module_function :debug?

      def debug; end
      module_function :debug
    end

    module Enabled
      LOG_LEVEL = Logger::DEBUG

      def debug?
        true
      end
      module_function :debug?

      def debug
        yield
      end
      module_function :debug
    end
  end
end
