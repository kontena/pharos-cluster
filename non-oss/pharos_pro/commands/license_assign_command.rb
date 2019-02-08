# frozen_string_literal: true

module Pharos
  class LicenseAssignCommand < UpCommand
    include Pharos::Logging

    LICENSE_SERVICE_ENDPOINT = 'https://get.pharos.sh/api/licenses/%<key>s/assign'

    parameter "[LICENSE_KEY]", "kontena pharos license key"
    option '--description', 'DESCRIPTION', "license description"

    def default_description
      "pharos version #{Pharos.version} on #{master_host.address}"
    end

    def default_license_key
      prompt.ask('Enter Kontena Pharos license key:')
    end

    def config
      @config ||= load_config
    end

    def execute
      validate_license_format

      ssh.exec!("kubectl create secret generic pharos-cluster --namespace=kube-system --from-literal=key=#{subscription_token} --dry-run -o yaml | kubectl apply -f -")
      logger.info "Added subscription token to pharos cluster secrets"
    end

    def validate_license_format
      signal_usage_error 'invalid LICENSE_KEY format' unless license_key.match?(/^\h{8}-(?:\h{4}-){3}\h{12}$/)
    end

    def ssh
      @ssh ||= master_host.ssh
    end

    def master_host
      @master_host ||= config.master_hosts.first
    end

    def subscription_token_request
      logger.info "Exchanging license key for a subscription token"
      http_client.post(
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
          'User-Agent' => "pharos-cluster/#{Pharos.version}"
        }
      )
    end

    def subscription_token
      response = JSON.parse(subscription_token_request.body)
      signal_error response['errors'].map { |error| error['title'] }.join(', ') if response['errors']
      response.dig('data', 'attributes', 'license-token', 'token') || signal_error('invalid response')
    end

    def http_client
      Excon
    end
  end
end
