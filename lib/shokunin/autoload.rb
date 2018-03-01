autoload :Kubeclient, 'kubeclient'
autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :RestClient, 'rest-client'
autoload :Pastel, 'pastel'
autoload :Logger, 'logger'

module Shokunin
  autoload :Types, 'shokunin/types'
  autoload :Config, 'shokunin/config'
  autoload :ConfigSchema, 'shokunin/config_schema'
  autoload :Kube, 'shokunin/kube'
  autoload :Erb, 'shokunin/erb'
  autoload :AddonManager, 'shokunin/addon_manager'

  module SSH
    autoload :Client, 'shokunin/ssh/client'
  end

  module Phases
  end

  module Addons
  end
end