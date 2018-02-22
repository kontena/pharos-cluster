module Kontadm::Services
  class ConfigureNetwork

    def initialize(master)
      @master = master
    end

    def call
      ensure_passwd
      ensure_resources
    end

    def ensure_passwd
      kube_client = Kontadm::Kube.client(@master.address)
      begin
        kube_client.get_secret('weave-passwd', 'kube-system')
      rescue Kubeclient::ResourceNotFoundError
        weave_passwd = Kubeclient::Resource.new({
          metadata: {
            name: 'weave-passwd',
            namespace: 'kube-system'
          },
          data: {
            'weave-passwd': Base64.strict_encode64(generate_password)
          }
        })
        kube_client.create_secret(weave_passwd)
      end
    end

    def ensure_resources
      resources.each do |resource|
        Kontadm::Kube.apply_resource(@master.address, resource)
      end
    end

    def generate_password
      SecureRandom.hex(24)
    end

    # @return [Array<Kubeclient::Resource]
    def resources
      data = File.read(File.realpath(File.join(__dir__, '../resources/weave/weave.yml')))
      list = YAML.load(data)
      list['items'].map { |item| Kubeclient::Resource.new(item) }
    end
  end
end