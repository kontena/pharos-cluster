# frozen_string_literal: true

require 'bcrypt'
require 'json'

Pharos.addon 'kontena-lens' do
  version '1.3.4'
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
    patch_old_resource

    host = config.host || "lens.#{gateway_node_ip}.nip.io"
    name = config.name || 'pharos-cluster'
    apply_resources(
      host: host,
      email: config.tls&.email,
      tls_enabled: tls_enabled?,
      user_management: user_management_enabled?
    )
    protocol = tls_enabled? ? 'https' : 'http'
    message = "Kontena Lens is configured to respond at: " + pastel.cyan("#{protocol}://#{host}")
    if lens_configured?
      update_lens_name(name) if configmap.data.clusterName != name
    else
      unless admin_exists?
        create_admin_user(admin_password)
      end
      unless config_exists?
        create_config(name, "https://#{master_host_ip}:6443")
      end
      message << "\nStarting up Kontena Lens the first time might take couple of minutes, until that you'll see 503 with the address given above."
      message << "\nYou can sign in with the following admin credentials (you won't see these again): " + pastel.cyan("admin / #{admin_password}")
    end
    post_install_message(message)
  }

  def patch_old_resource
    last_config_annotation = "kubectl.kubernetes.io/last-applied-configuration"

    user_mgmt_deployment = kube_client.api('apps/v1').resource('deployments', namespace: 'kontena-lens').get('user-management')
    last_applied_string = user_mgmt_deployment.dig('metadata', 'annotations', last_config_annotation)
    return false unless last_applied_string
    last_applied = JSON.parse(last_applied_string)
    nested_replicas = last_applied.dig('spec', 'template', 'spec', 'replicas')
    if nested_replicas
      last_applied['spec']['template']['spec'].delete('replicas')
      patch = { metadata: { annotations: {} } }
      patch[:metadata][:annotations][last_config_annotation] = JSON.generate(last_applied)
      kube_client.api('apps/v1').resource('deployments', namespace: 'kontena-lens').merge_patch('user-management', patch)
      return true
    end
    false
  rescue K8s::Error::NotFound
    false
  end

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
  # @param kubernetes_api_url [String]
  # @return [K8s::Resource]
  def create_config(name, kubernetes_api_url)
    config = K8s::Resource.new(
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'config',
        namespace: 'kontena-lens'
      },
      data: {
        clusterName: name,
        clusterUrl: kubernetes_api_url
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

  def tls_enabled?
    config.tls&.enabled != false
  end

  def user_management_enabled?
    config.user_management&.enabled != false
  end

  # @return [String, NilClass]
  def master_host_ip
    cluster_config.master_host&.address
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
