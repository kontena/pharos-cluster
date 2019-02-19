# frozen_string_literal: true

autoload :Base64, 'base64'
autoload :SecureRandom, 'securerandom'
autoload :YAML, 'yaml'
autoload :JSON, 'json'
autoload :RestClient, 'rest-client'
autoload :Pastel, 'pastel'
autoload :Logger, 'logger'
autoload :Rouge, 'rouge'
autoload :K8s, 'k8s-client'
autoload :Excon, 'excon'
autoload :K8s, 'k8s-client'
autoload :Open3, 'open3'
autoload :Pathname, 'pathname'

module TTY
  autoload :Prompt, 'tty-prompt'
  autoload :Reader, 'tty-reader'
end

module Pharos
  autoload :Retry, 'pharos/retry'
  autoload :Types, 'pharos/types'
  autoload :Config, 'pharos/config'
  autoload :ConfigSchema, 'pharos/config_schema'
  autoload :Kube, 'pharos/kube'
  autoload :Kubeadm, 'pharos/kubeadm'
  autoload :YamlFile, 'pharos/yaml_file'
  autoload :Addon, 'pharos/addon'
  autoload :AddonManager, 'pharos/addon_manager'
  autoload :Phase, 'pharos/phase'
  autoload :Phases, 'pharos/phases'
  autoload :PhaseManager, 'pharos/phase_manager'
  autoload :Logging, 'pharos/logging'
  autoload :ClusterManager, 'pharos/cluster_manager'
  autoload :Transport, 'pharos/transport'

  module Transport
    autoload :TransportFile, 'pharos/transport/transport_file'
    autoload :Tempfile, 'pharos/transport/tempfile'
    autoload :Base, 'pharos/transport/base'
    autoload :Local, 'pharos/transport/local'
    autoload :SSH, 'pharos/transport/ssh'
    autoload :InteractiveSSH, 'pharos/transport/interactive_ssh'

    module Command
      autoload :SSH, 'pharos/transport/command/ssh'
      autoload :Local, 'pharos/transport/command/local'
      autoload :Result, 'pharos/transport/command/result'
    end
  end

  module Kube
    autoload :Stack, 'pharos/kube/stack'
    autoload :Config, 'pharos/kube/config'
  end

  module CommandOptions
    autoload :FilteredHosts, 'pharos/command_options/filtered_hosts'
    autoload :LoadConfig, 'pharos/command_options/load_config'
    autoload :Yes, 'pharos/command_options/yes'
  end

  module CoreExt
    autoload :IPAddrLoopback, 'pharos/core-ext/ip_addr_loopback'
    autoload :DeepTransformKeys, 'pharos/core-ext/deep_transform_keys'
    autoload :StringCasing, 'pharos/core-ext/string_casing'
  end

  module Terraform
    autoload :JsonParser, 'pharos/terraform/json_parser'
  end

  autoload :Configuration, 'pharos/configuration'

  module Configuration
    autoload :Host, 'pharos/configuration/host'
    autoload :Taint, 'pharos/configuration/taint'
    autoload :OsRelease, 'pharos/configuration/os_release'
  end

  module Etcd
    autoload :Client, 'pharos/etcd/client'
  end

  module Host
    autoload :Configurer, 'pharos/host/configurer'
  end
end
