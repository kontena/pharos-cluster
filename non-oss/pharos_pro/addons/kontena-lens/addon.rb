# frozen_string_literal: true

require 'bcrypt'

Pharos.addon 'kontena-lens' do
  version '1.2.0'
  license 'Kontena License'
  priority 10

  config_schema {
    optional(:name).filled(:str?)
    optional(:host).filled(:str?)
    optional(:tls).schema do
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
      user_management: user_management_enabled?
    )
    message = "Kontena Lens is configured to respond at: " + pastel.cyan("https://#{host}")
    if lens_configured?
      update_lens_name(name) if configmap.data.clusterName != name
    else
      unless admin_exists?
        create_admin_user(admin_password)
      end
      unless config_exists?
        create_config(name, host)
      end
      message << "\nStarting up Kontena Lens the first time might take couple of minutes, until that you'll see 503 with the address given above."
      message << "\nYou can sign in with the following admin credentials (you won't see these again): " + pastel.cyan("admin / #{admin_password}")
    end
    post_install_message(message)
  }

  # @return [Boolean]
  def admin_exists?
    kube_client.api('beta.kontena.io/v1').resource('users').get('admin')
    true
  rescue K8s::Error::NotFound
    false
  end

  # @param admin_password [String]
  # @return [K8s::Resource]
  def create_admin_user(admin_password)
    admin = K8s::Resource.new(
      apiVersion: 'beta.kontena.io/v1',
      kind: 'User',
      metadata: {
        name: 'admin'
      },
      spec: {
        username: 'admin',
        passwordDigest: BCrypt::Password.create(admin_password)
      }
    )
    kube_client.api('beta.kontena.io/v1').resource('users').create_resource(admin)
  end

  # @return [Boolean]
  def config_exists?
    kube_client.api('v1').resource('configmaps').get('config', namespace: 'kontena-lens')
    true
  rescue K8s::Error::NotFound
    false
  end

  # @param name [String]
  # @param host [String]
  # @return [K8s::Resource]
  def create_config(name, host)
    config = K8s::Resource.new(
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'config',
        namespace: 'kontena-lens'
      },
      data: {
        clusterName: name,
        clusterUrl: host
      }
    )
    kube_client.api('v1').resource('configmaps').create_resource(config)
  end

  def pastel
    @pastel ||= Pastel.new
  end

  # @return [Pharos::Configuration::Host]
  def gateway_node
    cluster_config.worker_hosts.first || cluster_config.master_hosts.first
  end

  # @return [String, NilClass]
  def gateway_node_ip
    gateway_node&.address
  end

  def user_management_enabled?
    config.user_management&.enabled != false
  end

  # @return [Pharos::Configuration::TokenWebhook]
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

  # @return [String]
  def admin_password
    @admin_password ||= SecureRandom.hex(8)
  end

  def lens_configured?
    !configmap.nil?
  end

  # @return [K8s::Resource, NilClass]
  def configmap
    @configmap ||= kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').get('config')
  rescue K8s::Error::NotFound
    nil
  end

  # @param new_name [String]
  # @return [K8s::Resource]
  def update_lens_name(new_name)
    configmap.data.clusterName = new_name
    kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').update_resource(configmap)
  end

  def ssh
    @ssh ||= gateway_node&.ssh
  end
end
