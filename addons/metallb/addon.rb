# frozen_string_literal: true

Pharos.addon 'metal-lb' do
  version '0.7.3'
  license 'Apache License 2.0'

  config {
    attribute :address_pools, Pharos::Types::Array
    attribute :peers, Pharos::Types::Array
  }

  config_schema {
    required(:address_pools).filled(min_size?: 1) do
      each do
        schema do
          required(:name).filled(:str?)
          required(:protocol).filled(:str?)
          required(:addresses).each(:str?)
          optional(:auto_assign).filled(:bool?)
        end
      end
    end

    optional(:peers) do
      each do
        schema do
          required(:peer_address).filled(:str?)
          required(:peer_asn).filled(:int?)
          required(:my_asn).filled(:int?)
          optional(:node_selectors).each(:hash?)
        end
      end
    end
  }

  install {
    # Load the base stack
    stack = kube_stack(
      version: self.class.version,
      image_repository: cluster_config.image_repository
    )
    stack.resources << build_config
    stack.apply(kube_client)
  }

  def validate
    super
    # Validate BGP peers exist if BGP used
    return unless config.address_pools.count { |pool| pool.dig(:protocol) == 'bgp' }.positive?
    raise Pharos::InvalidAddonError, "Peers have to be configured for BGP protocol" if config.peers.nil? || config.peers.empty?
  end

  def build_config
    # cfg is using string keys to get the output yaml correct as it's used as plain string
    cfg = {
      'address-pools' => config.address_pools.map { |pool|
        {
          'name' => pool[:name],
          'protocol' => pool[:protocol],
          'addresses' => pool[:addresses]
        }
      }
    }

    if config.address_pools.count { |pool| pool.dig(:protocol) == 'bgp' }.positive?
      cfg['peers'] = config.peers.map { |peer|
        {
          'peer-address' => peer[:peer_address],
          'peer-asn' => peer[:peer_asn],
          'my-asn' => peer[:my_asn],
          'node-selectors' => peer[:node_selectors]
        }
      }
    end

    configmap = K8s::Resource.new(
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        namespace: 'metallb-system',
        name: 'config'
      },
      data: {
        config: cfg.to_yaml.gsub(/^---\n/, '')
      }
    )

    configmap
  end
end
