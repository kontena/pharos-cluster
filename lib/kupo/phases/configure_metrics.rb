require_relative 'base'

module Kupo::Phases
  class ConfigureMetrics < Base

    register_component(Kupo::Phases::Component.new(
      name: 'metrics-server', version: '0.2.1', license: 'Apache License 2.0'
    ))

    register_component(Kupo::Phases::Component.new(
      name: 'heapster', version: '1.5.1', license: 'Apache License 2.0'
    ))

    # @param master [Kupo::Configuration::Host]
    def initialize(master)
      @master = master
    end

    def call
      logger.info { "Configuring metrics-server ..." }
      Kupo::Kube.apply_stack(@master.address, 'metrics-server', {
        version: '0.2.1', arch: @master.cpu_arch
      })
      logger.info { "Configuring heapster ..." }
      Kupo::Kube.apply_stack(@master.address, 'heapster', {
        version: '1.5.1', arch: @master.cpu_arch
      })
    end
  end
end
