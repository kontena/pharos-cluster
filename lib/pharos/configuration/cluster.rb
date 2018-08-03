# frozen_string_literal: true

require 'pharos/configuration/kube_config'

module Pharos
  module Configuration
    class Cluster < Pharos::Configuration::Struct
      attribute :name, Pharos::Types::String.optional
      attribute :kube_config, Pharos::Configuration::KubeConfig.optional
    end
  end
end
