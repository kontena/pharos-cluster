# frozen_string_literal: true

module Pharos
  class HostConfigManager
    # @return [Array<Class<Pharos::Host::Configurer>>]
    def self.load_configs
      Dir.glob(File.join(__dir__, 'host', '**', '*.rb')).each { |f| require(f) }
      Pharos::Host::Configurer.configs
    end
  end
end
