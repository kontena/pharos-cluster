module Kontadm::Services
  class ConfigureMetrics

    def initialize(master)
      @master = master
    end

    def call
      Kontadm::Kube.apply_stack(@master.address, 'metrics-server')
    end
  end
end