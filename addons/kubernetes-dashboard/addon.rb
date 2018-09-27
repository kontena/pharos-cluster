# frozen_string_literal: true

Pharos.addon 'kubernetes-dashboard' do
  version '1.8.3'
  license 'Apache License 2.0'

  install {
    apply_resources(heapster_version: '1.5.1')

    logger.info { "~~> kubernetes-dashboard can be accessed via kubectl proxy. Check proxy URL with: kubectl cluster-info" }

    retry_times = 0
    begin
      service_account = kube_client.api('v1').resource('serviceaccounts', namespace: 'kube-system').get('dashboard-admin')
      raise "secret not available" if service_account.secrets.nil? || service_account.secrets.empty?
      token_secret = service_account.secrets[0]
      logger.info { "~~> kubernetes-dashboard admin token can be fetched using: kubectl describe secret #{token_secret.name} -n kube-system" }
    rescue => ex
      raise unless ex.message == "secret not available"
      retry_times += 1
      if retry_times > 10
        logger.error { "~~> kubernetes-dashboard admin token cannot be found" }
      else
        logger.send(retry_times == 1 ? :info : :debug) { "Waiting for secrets to update .." }
        sleep 5
        retry
      end
    end
  }
end
