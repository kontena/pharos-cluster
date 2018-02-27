require_relative 'base'

module Shokunin::Phases
  class ConfigureKured < Base

    register_component(Shokunin::Phases::Component.new(
      name: 'kured', version: '1.0.0', license: 'Apache License 2.0'
    ))

    # @param master [Shokunin::Configuration::Host]
    # @param master [Shokunin::Configuration::Feature::HostUpdate]
    def initialize(master, config)
      @master = master
      @config = config
    end

    def call
      if @config.interval
        logger.info { "Enabling automatic host security updates (interval: #{@config.interval}) ..." }
        interval = Fugit::Duration.parse(@config.interval).to_sec
        Shokunin::Kube.apply_stack(@master.address, 'host-upgrades', {
          interval: interval
        })
      else
        logger.info { "Disabling automatic host security updates ..." }
        Shokunin::Kube.prune_stack(@master.address, 'host-upgrades', '-')
      end

      if @config.reboot
        logger.info { "Enabling automatic host reboots ..." }
        Shokunin::Kube.apply_stack(@master.address, 'kured')
      else
        logger.info { "Disabling automatic host reboots ..." }
        Shokunin::Kube.prune_stack(@master.address, 'kured', '-')
      end
    end
  end
end