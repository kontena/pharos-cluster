# frozen_string_literal: true

module Pharos
  class LicenseAssignCommand < UpCommand

    include Pharos::Logging

    LICENSE_SERVICE_ENDPOINT = "https://get.pharos.sh/api/licenses/%<key>s/assign".freeze

    parameter "[LICENSE_KEY]", "kontena pharos license key"
    option '--description', 'DESCRIPTION', "license description"

    def default_description
      "pharos version #{Pharos::VERSION} on #{master_host.address}"
    end

    def default_license_key
      prompt.ask('Enter Kontena Pharos license key:')
    end

    def config
      @config ||= load_config
    end

    def execute
      signal_usage_error 'invalid LICENSE_KEY format' unless license_key.match?(/^\h{8}-(?:\h{4}-){3}\h{12}$/)
      retry_times = 0
      ssh.exec!("kubectl create secret generic pharos-cluster --namespace=kube-system --from-literal=key=#{subscription_token.shellescape}")
      logger.info "Add subscription token to pharos cluster secrets"
    rescue K8s::Error::NotFound
      retry_times += 1
      raise if retry_times > 1
      ssh.exec!("kubectl delete secret pharos-cluster --namespace=kube-system")
      logger.info "Deleted existing subscription token from pharos cluster secrets"
      retry
    end

    def ssh
      @ssh ||= Pharos::SSH::Manager.new.client_for(master_host)
    end

    def master_host
      @master_host ||= config.master_hosts.first
    end

    def subscription_token_request
      logger.info "Exchanging license key for a subscription token"
      Excon.post(
        LICENSE_SERVICE_ENDPOINT % { key: license_key },
        body: JSON.dump(
          data: {
            attributes: {
              description: description
            }
          }
        ),
        headers: {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'User-Agent' => "pharos-cluster/#{Pharos::VERSION}"
        }
      )
    end

    def subscription_token
      response = JSON.parse(subscription_token_request.body)
      signal_error response['errors'].map { |error| error['title'] }.join(', ') if response['errors']
      response.dig('data', 'attributes', 'license-token', 'token') || signal_error('invalid response')
    end
  end
end
