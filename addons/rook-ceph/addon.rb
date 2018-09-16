# frozen_string_literal: true

Pharos.addon 'rook-ceph' do
  version '0.8.1'
  license 'Apache License 2.0'

  config_schema {
    required(:dataDirHostPath).filled(:str?)
    required(:storage).schema
    optional(:placement).schema
    optional(:resources).schema
    optional(:dashboard).schema do
      required(:enabled).filled(:bool?)
    end

  }
end
