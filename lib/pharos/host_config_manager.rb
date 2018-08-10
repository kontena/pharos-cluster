# frozen_string_literal: true

module Pharos
  class HostConfigManager
    # @param cluster_config [Pharos::Config]
    # @return [Array<Class<Pharos::Host::Configurer>>]
    def self.load_configs(cluster_config)
      Pharos::Host::Configurer.cluster_config = cluster_config
      Dir.glob(File.join(__dir__, 'host', '**', '*.rb')).each { |f| require(f) }
      Pharos::Host::Configurer.configs.map { |configurer|
        configurer.cluster_config = cluster_config
        configurer
      }
    end
  end
end
