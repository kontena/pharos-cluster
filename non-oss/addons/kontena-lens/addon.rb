# frozen_string_literal: true

Pharos.addon 'kontena-lens' do
  version '1.0.0-beta.1'
  license 'Kontena License'

  config_schema {
    optional(:host).filled(:str?)
    optional(:email).filled(:str?)
  }

  def worker_node_ip
    worker_node = cluster_config.worker_hosts.first
    worker_node&.address
  end

  install {
    host = config.host || "lens.#{worker_node_ip}.nip.io"
    apply_resources(
      host: host
    )
    post_install_message("Kontena Lens is running at: https://#{host}")
  }
end
