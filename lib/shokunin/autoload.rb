autoload :Kubeclient, 'kubeclient'
autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :RestClient, 'rest-client'
autoload :Pastel, 'pastel'
autoload :Logger, 'logger'

module Shokunin
  autoload :Config, 'shokunin/config'
  autoload :ConfigSchema, 'shokunin/config_schema'
  autoload :Kube, 'shokunin/kube'
  autoload :Erb, 'shokunin/erb'

  module SSH
    autoload :Client, 'shokunin/ssh/client'
  end

  module Services
    autoload :ConfigureHost, 'shokunin/services/configure_host'
    autoload :ConfigureClient, 'shokunin/services/configure_client'
    autoload :ConfigureMaster, 'shokunin/services/configure_master'
    autoload :ConfigureNetwork, 'shokunin/services/configure_network'
    autoload :ConfigureKured, 'shokunin/services/configure_kured'
    autoload :ConfigureMetrics, 'shokunin/services/configure_metrics'
    autoload :JoinNode, 'shokunin/services/join_node'
    autoload :ValidateHost, 'shokunin/services/validate_host'
  end
end