# frozen_string_literal: true

module Pharos
  module Debug
    def self.module(env_key = 'DEBUG')
      ENV[env_key].to_s.empty? ? Disabled : Enabled
    end

    module Disabled
      LOG_LEVEL = :INFO

      private

      def debug?
        false
      end

      def if_debug; end
    end

    module Enabled
      LOG_LEVEL = :DEBUG

      private

      def debug?
        true
      end

      def if_debug
        yield
      end
    end
  end
end
