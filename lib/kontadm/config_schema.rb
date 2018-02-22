require 'dry-validation'

module Kontadm
  ConfigSchema = Dry::Validation.Form do
    required(:hosts).each do
      schema do
        required(:address).filled
        required(:role).filled
        optional(:user).filled
      end
    end
    optional(:features).each do
      schema do
        required(:name).filled
        optional(:options).value(type?: Hash)
      end
    end
  end
end