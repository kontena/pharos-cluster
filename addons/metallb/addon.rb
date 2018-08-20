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
        end
      end
    end

    optional(:peers) do
      each do
        schema do
          required(:peer_address).filled(:str?)
          required(:peer_asn).filled(:str?)
          required(:my_asn).filled(:str?)
          optional(:node_selectors).each(:hash?)
        end
      end
    end
  }

  def validate
    super
    # Validate BGP peers exist if BGP used
    return unless config.address_pools.count { |pool| pool.dig(:protocol) == 'bgp' }.positive?
    raise Pharos::InvalidAddonError, "Peers have to be configured for BGP protocol" if config.peers.nil? || config.peers.empty?
  end
end
