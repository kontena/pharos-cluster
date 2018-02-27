require_relative 'base'

module Shokunin::Phases
  class ConfigureMetrics < Base

    def initialize(master)
      @master = master
    end

    def call
      logger.info { "Configuring metrics server ..." }
      Shokunin::Kube.apply_stack(@master.address, 'metrics-server')
      logger.info { "Configuring heapster ..." }
      Shokunin::Kube.apply_stack(@master.address, 'heapster')
    end
  end
end