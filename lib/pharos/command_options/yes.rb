# frozen_string_literal: true

module Pharos
  module CommandOptions
    module Yes
      def self.included(base)
        base.option ['-y', '--yes'], :flag, 'answer automatically yes to prompts'
      end
    end
  end
end
