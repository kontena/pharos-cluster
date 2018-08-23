# frozen_string_literal: true

Pharos.addon 'nfs-provisioner' do
  version '1.1.0'
  license 'Apache License 2.0'

  config {
    attribute :storage_size, Pharos::Types::String
  }
end
