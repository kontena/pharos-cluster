require_relative 'base'

module Shokunin::Phases
  class ConfigureCertManager < Base

    register_component(Shokunin::Phases::Component.new(
      name: 'cert-manager', version: '0.2.3', license: 'Apache License 2.0'
    ))

    # @param master [Shokunin::Configuration::Host]
    def initialize(master)
      @master = master
    end

    def call
      logger.info { "Configuring cert-manager ..." }
      Shokunin::Kube.apply_stack(@master.address, 'cert-manager')
    end
  end
end