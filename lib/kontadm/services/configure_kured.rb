module Kontadm::Services
  class ConfigureKured

    def initialize(master, config)
      @master = master
      @config = config
    end

    def call
      ensure_resources
      cleanup_resources
    end

    def ensure_resources
      resources = []

      if @config.interval
        interval = Fugit::Duration.parse(@config.interval).to_sec
        resources += Kontadm::Kube.parse_resource_file('host-upgrades/daemonset.yml', {
          interval: interval
        })
      end

      if @config.reboot
        reboot_interval = @config.interval.nil? ? '1d' : @config.interval
        resources += Kontadm::Kube.parse_resource_file('kured/rbac.yml')
        resources += Kontadm::Kube.parse_resource_file('kured/daemonset.yml', {
          interval: reboot_interval
        })
      end
      resources.each do |resource|
        Kontadm::Kube.apply_resource(@master.address, resource)
      end
    end

    def cleanup_resources
      resources = []
      unless @config.interval
        resources += Kontadm::Kube.parse_resource_file('host-upgrades/daemonset.yml')
      end

      unless @config.reboot
        resources += Kontadm::Kube.parse_resource_file('kured/rbac.yml')
        resources += Kontadm::Kube.parse_resource_file('kured/daemonset.yml')
      end
      resources.each do |resource|
        Kontadm::Kube.delete_resource(@master.address, resource)
      end
    end
  end
end