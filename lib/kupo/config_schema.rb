require 'fugit'
require 'dry-validation'

module Kupo

  class ConfigSchema

    # @return [Dry::Validation::Schema]
    def self.build
      Dry::Validation.Form do
        configure do
          def self.messages
            super.merge(
              en: { errors: {network_dns_replicas: "network.dns_replicas cannot be larger than the number of hosts"}}
            )
          end
        end
        required(:hosts).filled(min_size?: 1) do
          each do
            schema do
              required(:address).filled
              required(:role).filled(included_in?: ['master', 'worker'])
              optional(:labels).filled
              optional(:private_address).filled
              optional(:user).filled
              optional(:ssh_key_path).filled
              optional(:container_engine).filled(included_in?: ['docker', 'cri-o'])
            end
          end
        end
        optional(:network).schema do
          optional(:dns_replicas).filled(:int?, gt?: 0)
          optional(:service_cidr).filled(:str?)
          optional(:pod_network_cidr).filled(:str?)
          optional(:trusted_subnets).each(type?: String)
        end
        optional(:addons).value(type?: Hash)

        validate(network_dns_replicas: [:network, :hosts]) do |network, hosts|
          if network && network[:dns_replicas]
            network[:dns_replicas] <= hosts.length
          else
            true
          end
        end
      end
    end
  end
end
