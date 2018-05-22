# frozen_string_literal: true

version '1.8.3'
license 'Apache License 2.0'

def install
  super

  logger.info { "~~> kubernetes-dashboard can be accessed via kubectl proxy at http://localhost:8001/ui" }

  kube_client = Pharos::Kube.client(@master.api_address)
  service_account = kube_client.get_service_account('dashboard-admin', 'kube-system')
  token_secret = service_account.secrets[0]
  return unless token_secret

  logger.info { "~~> kubernetes-dashboard admin token can be fetched using: kubectl describe secret #{token_secret.name} -n kube-system" }
end
