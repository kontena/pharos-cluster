# frozen_string_literal: true

Pharos.addon 'kontena-lens' do
  version '1.2.0'
  license 'Kontena License'
  priority 10

  config_schema {
    optional(:name).filled(:str?)
    optional(:host).filled(:str?)
    optional(:tls).schema do
      optional(:enabled).filled(:bool?)
      optional(:email).filled(:str?)
    end
    optional(:user_management).schema do
      optional(:enabled).filled(:bool?)
    end
    optional(:persistence).schema do
      optional(:enabled).filled(:bool?)
    end
    optional(:shell).schema do
      optional(:image).filled(:str?)
    end
  }

  modify_cluster_config {
    if user_management_enabled?
      cluster_config.set(:authentication, Pharos::Configuration::Authentication.new(token_webhook: token_authentication_webhook_config))
    end
  }

  install {
    host = config.host || "lens.#{gateway_node_ip}.nip.io"
    name = config.name || 'pharos-cluster'
    apply_resources(
      host: host,
      email: config.tls&.email,
      tls_enabled: tls_enabled?,
      user_management: user_management_enabled?
    )
    protocol = !tls_enabled? || config.tls&.email ? 'http' : 'https' # with cert-manager we have to use http since tls secret is not in place immediately
    wait_for_dashboard(protocol, host)
    message = "Kontena Lens is running at: " + pastel.cyan("https://#{host}")
    if lens_configured?
      update_lens_name(name) if configmap.data.clusterName != name
    else
      @retries = 1
      @max_retries = 3
      create_lens_config(name, protocol, host, admin_password)
      message << "\nYou can sign in with admin credentials: " + pastel.cyan("admin / #{admin_password}")
    end
    post_install_message(message)
  }

  def pastel
    @pastel ||= Pastel.new
  end

  def gateway_node
    cluster_config.worker_hosts.first || cluster_config.master_hosts.first
  end

  def gateway_node_ip
    gateway_node&.address
  end

  def master_host_ip
    cluster_config.master_host&.address
  end

  def tls_enabled?
    config.tls&.enabled != false
  end

  def user_management_enabled?
    config.user_management&.enabled != false
  end

  def token_authentication_webhook_config
    Pharos::Configuration::TokenWebhook.new(
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
  end

  def wait_for_dashboard(protocol, host)
    puts "    Waiting for Kontena Lens to get up and running ..."
    command = "sudo curl -LkIs -o /dev/null -w \"%{http_code}\" -H \"Host: #{host}\" #{protocol}://localhost/" # rubocop:disable Style/FormatStringToken
    response = ssh.exec(command)
    i = 1
    until response.output.to_i == 200
      sleep 10
      puts "    Still waiting... (#{i * 10}s elapsed)"
      i += 1
      response = ssh.exec(command)
    end
  end

  def admin_password
    @admin_password ||= SecureRandom.hex(8)
  end

  def lens_configured?
    !configmap.nil?
  end

  def configmap
    @configmap ||= kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').get('config')
  rescue K8s::Error::NotFound
    nil
  end

  def create_lens_config(name, protocol, host, admin_password)
    cluster_config = {
      clusterName: name,
      clusterUrl: "https://#{master_host_ip}:6443",
      adminPassword: admin_password
    }
    command = "sudo curl -iksL -X POST -d '#{cluster_config.to_json}' -H \"Host: #{host}\" -H \"Content-Type: application/json\" #{protocol}://localhost/api/cluster"
    result = ssh.exec(command)
    raise Pharos::InvalidAddonError, "Could not create Kontena Lens configuration" unless result.output.lines.include?("HTTP/1.1 200 OK\r\n")
  rescue Pharos::InvalidAddonError => e
    if @retries <= @max_retries
      @retries += 1
      timeout = 2**@retries
      puts "    #{e.message}"
      puts "    retrying after #{timeout} seconds"
      sleep timeout
      retry
    end
    raise Pharos::InvalidAddonError, e.message
  end

  def update_lens_name(new_name)
    configmap.data.clusterName = new_name
    kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').update_resource(configmap)
  end

  def ssh
    @ssh ||= Pharos::SSH::Manager.instance.client_for(gateway_node)
  end
end
