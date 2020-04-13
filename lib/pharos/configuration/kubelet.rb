# frozen_string_literal: true

module Pharos
  module Configuration
    class Kubelet < Pharos::Configuration::Struct
      attribute :read_only_port, Pharos::Types::Bool.default(false)
      attribute :feature_gates, Pharos::Types::Strict::Hash
      attribute :extra_args, Pharos::Types::Strict::Array.of(Pharos::Types::String)
      attribute :cpu_cfs_quota, Pharos::Types::Bool.default(true)
      attribute :cpu_cfs_quota_period, Pharos::Types::String
      attribute :system_reserved, Pharos::Types::Strict::Hash
      attribute :kube_reserved, Pharos::Types::Strict::Hash
    end
  end
end
