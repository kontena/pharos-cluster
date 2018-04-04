# frozen_string_literal: true

autoload :Kubeclient, 'kubeclient'
autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :RestClient, 'rest-client'
autoload :Pastel, 'pastel'
autoload :Logger, 'logger'

module Pharos
  autoload :Types, 'pharos/types'
  autoload :Config, 'pharos/config'
  autoload :ConfigSchema, 'pharos/config_schema'
  autoload :Kube, 'pharos/kube'
  autoload :Erb, 'pharos/erb'
  autoload :AddonManager, 'pharos/addon_manager'
  autoload :Phases, 'pharos/phases'

  module SSH
    autoload :Client, 'pharos/ssh/client'
    autoload :Tempfile, 'pharos/ssh/tempfile'
  end

  module Addons
  end
end
