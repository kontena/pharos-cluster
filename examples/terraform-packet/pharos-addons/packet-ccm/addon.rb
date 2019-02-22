# frozen_string_literal: true

class Pharos::Addons::PacketCcm < Pharos::Addon
  version '0.0.4'
  license 'Apache License 2.0'

  config {
    attribute :project_id, Pharos::Types::String.default(ENV['PACKET_PROJECT_ID'].to_s)
    attribute :api_key, Pharos::Types::String.default(ENV['PACKET_API_KEY'].to_s)
  }

  config_schema {
    required(:project_id).filled(:str?)
    required(:api_key).filled(:str?)
  }
end
