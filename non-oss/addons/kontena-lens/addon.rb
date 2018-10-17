# frozen_string_literal: true

Pharos.addon 'kontena-lens' do
  version '1.0.0'
  license 'Kontena License'

  config_schema {
    optional(:name).filled(:str?)
    optional(:host).filled(:str?)
    optional(:tls).schema do
      optional(:email).filled(:str?)
    end
    optional(:user_management).schema do
      optional(:enabled).filled(:bool?)
    end
  }

  modify_cluster_config {
    if user_management_enabled?
      configure_token_authentication_webhook
    end
  }

  install {
    Excon.defaults[:ssl_verify_peer] = false # Allow ingress controller default cert
    host = config.host || "lens.#{worker_node_ip}.nip.io"

    name = config.name || 'pharos-cluster'
    apply_resources(
      host: host,
      email: config.tls&.email,
      user_management: user_management_enabled?
    )
    wait_for_dashboard(host)
    message = "Kontena Lens is running at: " + pastel.cyan("https://#{host}")
    unless configmap
      init_cluster(name, host)
      message << "\nYou can sign in with admin credentials: " + pastel.cyan("admin / #{admin_password}")
    end
    post_install_message(message)
    Excon.defaults[:ssl_verify_peer] = true
  }

  def pastel
    @pastel ||= Pastel.new
  end

  def worker_node
    cluster_config.worker_hosts.first
  end

  def worker_node_ip
    worker_node&.address
  end

  def master_host_ip
    cluster_config.master_host&.address
  end

  def user_management_enabled?
    config.user_management&.enabled != false
  end

  def configure_token_authentication_webhook
    token_webhook_config = Pharos::Configuration::TokenWebhook.new(
      config: {
        cluster: {
          name: 'lens-authenticator',
          server: 'http://localhost:9292/token'
        },
        user: {
          name: 'kube-apiserver'
        }
      }
    )
    cluster_config.set(:authentication, Pharos::Configuration::Authentication.new(token_webhook: token_webhook_config))
  end

  def wait_for_dashboard(host)
    puts "    Waiting for Kontena Lens to get up and running"
    command = "sudo curl -kIs -o /dev/null -w \"%{http_code}\" -H \"Host: #{host}\" https://localhost" ## rubocop:disable Style/FormatStringToken
    response = ssh.exec(command)
    i = 1
    until response.success? && response.output.to_i == 200
      sleep 10
      puts "    Still waiting... (#{i * 10}s elapsed)"
      i += 1
      response = ssh.exec(command)
    end
  end

  def admin_password
    @admin_password ||= SecureRandom.hex(8)
  end

  def cluster_initialized?
    configmap.nil?
  end

  def configmap
    @configmap ||= kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').get('config')
  rescue K8s::Error::NotFound
    nil
  end

  def init_cluster(name, host)
    cluster_config = {
      clusterName: name,
      clusterUrl: "https://#{master_host_ip}:6443",
      adminPassword: admin_password
    }
    command = "sudo curl -X POST -d '#{cluster_config.to_json}' -ks -H \"Host: #{host}\" -H \"Content-Type: application/json\" https://localhost/api/cluster"
    ssh.exec(command)
  end

  def ssh
    @ssh ||= Pharos::SSH::Manager.new.client_for(worker_node)
  end
end
