require 'fugit'
require 'dry-validation'

module Kontadm
  ConfigSchema = Dry::Validation.Form do

    configure do
      def duration?(value)
        !Fugit::Duration.parse(value).nil?
      end

      def self.messages
        super.merge(
          en: { errors: { duration?: 'is not valid duration' } }
        )
      end
    end

    required(:hosts).each do
      schema do
        required(:address).filled
        required(:role).filled
        optional(:user).filled
        optional(:ssh_key_path).filled
      end
    end
    optional(:features).schema do
      optional(:host_updates).schema do
        required(:interval).filled(:str?, :duration?)
        required(:reboot).filled(:bool?)
      end
      optional(:network).schema do
        required(:settings).schema do
          required(:trusted_subnets).filled(:array?)
        end
      end
    end
  end
end