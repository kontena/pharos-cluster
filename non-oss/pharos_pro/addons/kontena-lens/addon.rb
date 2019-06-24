# frozen_string_literal: true

require 'bcrypt'
require 'json'

Pharos.addon 'kontena-lens' do
  version '1.6.0'
  license 'Kontena License'
  priority 10
  depends_on [
    'kontena-stats'
  ]

  helm_api_version = '1.6.0'
  terminal_gateway_version = '1.6.0'
  terminal_version = '1.6.0'
  user_management_version = '1.6.0'
  resource_applier_version = '1.6.0'
  authenticator_version = '1.6.0'
  redis_version = '4-alpine'
  tiller_version = '2.13.1'
  license_enforcer_version = '0.2.0'

  config_schema {
    optional(:name).filled(:str?)
    optional(:node_selector).filled(:hash?)
    optional(:tolerations).each(:hash?)
    optional(:ingress).schema do
      optional(:host).filled(:str?)
      optional(:tls).schema do
        optional(:enabled).filled(:bool?)
        optional(:email).filled(:str?)
      end
    end
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
      optional(:skip_refresh).filled(:bool?)
    end
    optional(:charts).schema do
      optional(:enabled).filled(:bool?)
      optional(:repositories).each do
        schema do
          required(:name).filled(:str?)
          required(:url).filled(:str?)
        end
      end
    end
  }

  modify_cluster_config {
    if user_management_enabled?
      cluster_config.set(:authentication, Pharos::Configuration::Authentication.new(token_webhook: token_authentication_webhook_config))
    end
  }

  install {
    patch_old_resource

    host = config.ingress&.host || config.host || "lens.#{gateway_node_ip}.nip.io"
    tls_email = config.ingress&.tls&.email || config.tls&.email
    name = config.name || cluster_config.name || 'pharos-cluster'
    cluster_url = kubernetes_api_url
    charts_enabled = config.charts&.enabled != false
    helm_repositories = config.charts&.repositories || [stable_helm_repo]
    apply_resources(
      helm_api_version: helm_api_version,
      terminal_gateway_version: terminal_gateway_version,
      terminal_version: terminal_version,
      user_management_version: user_management_version,
      resource_applier_version: resource_applier_version,
      authenticator_version: authenticator_version,
      license_enforcer_version: license_enforcer_version,
      redis_version: redis_version,
      tiller_version: tiller_version,
      host: host,
      email: tls_email,
      tls_enabled: tls_enabled?,
      charts_enabled: charts_enabled,
      user_management: user_management_enabled?,
      helm_repositories: helm_repositories.map{ |repo| "#{repo[:name]}=#{repo[:url]}" }.join(',')
    )
    protocol = tls_enabled? ? 'https' : 'http'
    message = "Kontena Lens is configured to respond at: " + "#{protocol}://#{host}".cyan
    message << "\nStarting up Kontena Lens the first time might take couple of minutes, until that you'll see 503 with the address given above."
    create_or_update_configmap(name, cluster_url)
    if user_management_enabled? && !admin_exists?
      create_admin_user(admin_password)
      message << "\nYou can sign in with the following admin credentials (you won't see these again): " + "admin / #{admin_password}".cyan
    end
    message << "\nWarning: `config.host` option is deprecated in favor of `config.ingress.host` option and will be removed in future." if config.host
    message << "\nWarning: `config.tls` option is deprecated in favor of `config.ingress.tls` option and will be removed in future." if config.tls
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

  # @param name [String]
  # @param cluster_url [String]
  # @return [K8s::Resource]
  def create_or_update_configmap(name, cluster_url)
    if config_exists?
      update_configmap(name, cluster_url)
    else
      create_configmap(name, cluster_url)
    end
  end

  # @return [String]
  def kubernetes_api_url
    endpoint = cluster_config.api&.endpoint || master_host_ip
    "https://#{endpoint}:6443"
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

  # @param name [String]
  # @param cluster_url [String]
  # @return [K8s::Resource]
  def create_configmap(name, cluster_url)
    config = K8s::Resource.new(
      apiVersion: 'v1',
      kind: 'ConfigMap',
      metadata: {
        name: 'config',
        namespace: 'kontena-lens'
      },
      data: {
        clusterName: name,
        clusterUrl: cluster_url
      }
    )
    kube_client.api('v1').resource('configmaps').create_resource(config)
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
    config.ingress&.tls&.enabled != false && config.tls&.enabled != false
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

  def config_exists?
    !configmap.nil?
  end

  # @return [K8s::Resource, NilClass]
  def configmap
    @configmap ||= kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').get('config')
  rescue K8s::Error::NotFound
    nil
  end

  # @param name [String]
  # @param cluster_url [String]
  # @return [K8s::Resource]
  def update_configmap(name, cluster_url)
    configmap.data.clusterName = name
    configmap.data.clusterUrl = cluster_url
    kube_client.api('v1').resource('configmaps', namespace: 'kontena-lens').update_resource(configmap)
  end

  def ssh
    @ssh ||= gateway_node&.ssh
  end

  def stable_helm_repo
    {
      name: 'stable',
      url: 'https://kubernetes-charts.storage.googleapis.com'
    }
  end
end
