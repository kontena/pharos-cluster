# frozen_string_literal: true

Pharos.addon('drone-ci') do
  drone_version '0.8.5'
  version "#{drone_version}+kontena.1"
  license 'Kontena License'

  config_schema {
    required(:organizations).each(:str?)
    required(:admins).each(:str?)
    required(:remote_config).filled(:str?)
    optional(:ingress).schema do
      required(:host).filled(:str?)
      optional(:tls).schema do
        required(:email).filled(:str?)
      end
    end
  }

  install {
    apply_resources(
      drone_version: drone_version,
      secret: server_secret,
      remote_config: remote_config
    )
  }

  def validate
    super

    raise Pharos::InvalidAddonError, "cannot read given remote.config file" unless File.readable?(config.remote_config)
    raise Pharos::InvalidAddonError, "remote_config needs to be configured" if remote_config_count.zero?
    raise Pharos::InvalidAddonError, "only one remote_config provider can be configured" if remote_config_count > 1
  end

  def remote_config_count
    count = 0

    count += 1 if remote_config.github
    count += 1 if remote_config.gitlab

    count
  end

  # @return [String]
  def server_secret
    secret = kube_client.api('v1').resource('secrets', namespace: 'drone-ci').get('drone-secrets')
    secret.data['server.secret'] || generate_secret
  rescue K8s::Error::NotFound
    generate_secret
  end

  # @return [RecursiveOpenStruct]
  def remote_config
    file = File.realpath(config.remote_config)
    RecursiveOpenStruct.new(YAML.safe_load(File.read(file)))
  end

  # @return [String]
  def generate_secret
    SecureRandom.hex(24)
  end
end