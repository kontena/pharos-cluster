autoload :Kubeclient, 'kubeclient'
autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :RestClient, 'rest-client'
autoload :Fugit, 'fugit'

module Kontadm
  autoload :Config, 'kontadm/config'
  autoload :ConfigSchema, 'kontadm/config_schema'
  autoload :Kube, 'kontadm/kube'
  autoload :Erb, 'kontadm/erb'

  module SSH
    autoload :Client, 'kontadm/ssh/client'
  end

  module Services
    autoload :ConfigureHost, 'kontadm/services/configure_host'
    autoload :ConfigureClient, 'kontadm/services/configure_client'
    autoload :ConfigureMaster, 'kontadm/services/configure_master'
    autoload :ConfigureNetwork, 'kontadm/services/configure_network'
    autoload :ConfigureKured, 'kontadm/services/configure_kured'
    autoload :JoinNode, 'kontadm/services/join_node'
    autoload :ValidateHost, 'kontadm/services/validate_host'
  end
end