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
  autoload :YamlFile, 'pharos/yaml_file'
  autoload :AddonManager, 'pharos/addon_manager'
  autoload :Phases, 'pharos/phases'

  module SSH
    autoload :Client, 'pharos/ssh/client'
  end

  module Terraform
    autoload :JsonParser, 'pharos/terraform/json_parser'
  end

  module Addons
  end
end
