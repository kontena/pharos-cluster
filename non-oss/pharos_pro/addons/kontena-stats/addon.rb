# frozen_string_literal: true

Pharos.addon('kontena-stats') do
  prometheus_version = '2.6.1'
  version "#{prometheus_version}+kontena.1"
  license 'Kontena License'

  config {
    attribute :replicas, Pharos::Types::Integer.default(1)
    attribute :tolerations, Pharos::Types::Array.default([])
    attribute :node_selector, Pharos::Types::Hash.default({})
  }

  config_schema {
    optional(:replicas).filled(:int?)
    optional(:tolerations).each(:hash?)
    optional(:node_selector).filled(:hash?)
  }

  install {
    apply_resources(
      prometheus_version: prometheus_version
    )
  }
end
