require_relative 'base'

module Shokunin::Phases
  class ConfigureIngress < Base

    register_component(Shokunin::Phases::Component.new(
      name: 'ingress-nginx', version: '0.11.0', license: 'Apache License 2.0'
    ))

    # @param master [Shokunin::Configuration::Host]
    def initialize(master)
      @master = master
    end

    def call
      logger.info { "Configuring nginx ingress controller ..." }
      Shokunin::Kube.apply_stack(@master.address, 'ingress-nginx')
    end
  end
end