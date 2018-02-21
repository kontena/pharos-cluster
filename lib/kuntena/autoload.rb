autoload :Kubeclient, 'kubeclient'
autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :RestClient, 'rest-client'

module TTY
  autoload :Spinner, 'tty/spinner'
end

module Kuntena
  autoload :Kube, 'kuntena/kube'

  module SSH
    autoload :Client, 'kuntena/ssh/client'
  end

  module Services
    autoload :ConfigureHost, 'kuntena/services/configure_host'
    autoload :ConfigureClient, 'kuntena/services/configure_client'
    autoload :ConfigureMaster, 'kuntena/services/configure_master'
    autoload :ConfigureNetwork, 'kuntena/services/configure_network'
    autoload :JoinNode, 'kuntena/services/join_node'
  end
end