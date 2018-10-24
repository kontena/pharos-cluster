# frozen_string_literal: true

module Pharos
  module CommandOptions
    module Yes
      def self.included(base)
        base.prepend(InstanceMethods)
        base.option ['-y', '--yes'], :flag, 'answer automatically yes to prompts'
      end

      module InstanceMethods
        def confirm_yes!(message)
          return if yes?

          if !$stdin.tty?
            warn('--yes required when running in non interactive mode')
            exit 1
          else
            exit 1 unless prompt.yes?(message, default: false)
          end
        rescue TTY::Reader::InputInterrupt
          warn 'Interrupted'
          exit 1
        end
      end
    end
  end
end
