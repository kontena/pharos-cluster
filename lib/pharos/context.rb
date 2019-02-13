# frozen_string_literal: true

module Pharos
  class Context < Pharos::Configuration::Struct
    def self.settable_attribute(name, type, &block)
      attribute(name, type, &block)

      define_method("#{name}=") do |value|
        @attributes[name] = type.call(value)
      end
    end

    attribute :config, Pharos::Types::Instance(Pharos::Config)
    attribute :force, Pharos::Types::Strict::Bool.default(false)
    settable_attribute :previous_config, Pharos::Config
    settable_attribute :previous_configmap, Pharos::Types::Instance(K8s::Resource)
    settable_attribute :existing_pharos_version, Pharos::Types::Strict::String
    settable_attribute :unsafe_upgrade, Pharos::Types::Strict::Bool.default(false)
    settable_attribute :api_upgraded, Pharos::Types::Strict::Bool
    settable_attribute :join_command, Pharos::Types::Strict::String
    settable_attribute :kube_config, Pharos::Types::Strict::Hash
    settable_attribute :post_install_messages, Pharos::Types::Strict::Hash.default(proc { {} })
    settable_attribute :etcd_ca, Pharos::Types::Strict::Hash
    settable_attribute :etcd_initial_cluster_state, Pharos::Types::Strict::String.enum('existing', 'new')
    settable_attribute :master_certs, Pharos::Types::Strict::Hash
    settable_attribute :secrets_encryption_keys, Pharos::Types::Strict::Hash

    alias force? force
    alias api_upgraded? api_upgraded
    alias unsafe_upgrade? unsafe_upgrade

    def master_ssh
      config.master_host.ssh
    end

    def kube_client
      return @kube_client if @kube_client

      @kube_client = Pharos::Kube.client(kube_api_address, k8s_config, kube_api_port)
    end

    def reset_kube_client
      @kube_client = nil
    end

    private

    def kube_api_port
      return 6443 unless master_host.bastion

      master_host.bastion.host.ssh.gateway(master_host.api_address, 6443)
    end

    def kube_api_address
      return 'localhost' if master_host.bastion

      master_host.api_address
    end

    def k8s_config
      raise "no kube_config available" if kube_config.nil?

      K8s::Config.new(kube_config)
    end

    def master_host
      config.master_host
    end
  end
end
