module Kontadm::Services
  class ConfigureKured

    # @param master [Kontadm::Configuration::Host]
    # @param master [Kontadm::Configuration::Feature::HostUpdate]
    def initialize(master, config)
      @master = master
      @config = config
    end

    def call
      if @config.interval
        interval = Fugit::Duration.parse(@config.interval).to_sec
        Kontadm::Kube.apply_stack(@master.address, 'host-upgrades', {
          interval: interval
        })
      else
        Kontadm::Kube.prune_stack(@master.address, 'host-upgrades', '-')
      end

      if @config.reboot
        reboot_interval = @config.interval.nil? ? '1d' : @config.interval
        Kontadm::Kube.apply_stack(@master.address, 'kured', {
          interval: reboot_interval
        })
      else
        Kontadm::Kube.prune_stack(@master.address, 'kured', '-')
      end
    end
  end
end