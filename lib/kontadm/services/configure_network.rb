module Kontadm::Services
  class ConfigureNetwork

    def initialize(master, config)
      @master = master
      @config = config
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
      Kontadm::Kube.apply_stack(@master.address, 'weave')
    end

    def generate_password
      SecureRandom.hex(24)
    end
  end
end