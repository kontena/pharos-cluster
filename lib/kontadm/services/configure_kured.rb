module Kontadm::Services
  class ConfigureKured

    def initialize(master)
      @master = master
    end

    def call
      ensure_resources
    end

    def ensure_resources
      resources.each do |resource|
        Kontadm::Kube.apply_resource(@master.address, resource)
      end
    end

    # @return [Array<Kubeclient::Resource]
    def resources
      resources = []

      data = File.read(File.realpath(File.join(__dir__, '../resources/host-upgrades/daemonset.yml')))
      data.split('---').each do |yaml|
        resources << Kubeclient::Resource.new(YAML.load(yaml))
      end

      data = File.read(File.realpath(File.join(__dir__, '../resources/kured/rbac.yml')))
      data.split('---').each do |yaml|
        resources << Kubeclient::Resource.new(YAML.load(yaml))
      end

      data = File.read(File.realpath(File.join(__dir__, '../resources/kured/daemonset.yml')))
      data.split('---').each do |yaml|
        resources << Kubeclient::Resource.new(YAML.load(yaml))
      end

      resources
    end
  end
end