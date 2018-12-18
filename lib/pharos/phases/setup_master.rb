# frozen_string_literal: true

module Pharos
  module Phases
    class SetupMaster < Pharos::Phase
      title "Setup master configuration files"

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def call
        push_external_etcd_certs if @config.etcd&.certificate
        push_audit_policy if @config.audit
        push_audit_config if @config.audit&.webhook&.server
        push_authentication_token_webhook_config if @config.authentication&.token_webhook
        push_cloud_config if @config.cloud&.config
      end

      # TODO: lock down permissions on key
      def push_external_etcd_certs
        logger.info { "Pushing external etcd certificates ..." }

        ssh.exec!('sudo mkdir -p /etc/pharos/etcd')
        ssh.file('/etc/pharos/etcd/ca-certificate.pem').write(File.open(@config.etcd.ca_certificate))
        ssh.file('/etc/pharos/etcd/certificate.pem').write(File.open(@config.etcd.certificate))
        ssh.file('/etc/pharos/etcd/certificate-key.pem').write(File.open(@config.etcd.key))
      end

      def push_audit_policy
        ssh.exec!("sudo mkdir -p /etc/pharos/audit")
        ssh.file("/etc/pharos/audit/policy.yml").write(parse_resource_file('audit/policy.yml'))
      end

      def push_audit_config
        logger.info { "Pushing audit configs to master ..." }
        ssh.exec!("sudo mkdir -p /etc/pharos/audit")
        ssh.file("/etc/pharos/audit/webhook.yml").write(
          parse_resource_file('audit/webhook-config.yml.erb', server: @config.audit.server)
        )
      end

      # @param webhook_config [Hash]
      def push_authentication_token_webhook_certs(webhook_config)
        logger.info { "Pushing token authentication webhook certificates ..." }

        ssh.exec!("sudo mkdir -p /etc/pharos/token_webhook")
        ssh.file('/etc/pharos/token_webhook/ca.pem').write(File.open(File.expand_path(webhook_config[:cluster][:certificate_authority]))) if webhook_config[:cluster][:certificate_authority]
        ssh.file('/etc/pharos/token_webhook/cert.pem').write(File.open(File.expand_path(webhook_config[:user][:client_certificate]))) if webhook_config[:user][:client_certificate]
        ssh.file('/etc/pharos/token_webhook/key.pem').write(File.open(File.expand_path(webhook_config[:user][:client_key]))) if webhook_config[:user][:client_key]
      end

      def push_authentication_token_webhook_config
        webhook_config = @config.authentication.token_webhook.config

        logger.info { "Pushing token authentication webhook config ..." }
        auth_token_webhook_config = kubeadm.generate_authentication_token_webhook_config(webhook_config)

        ssh.exec!('sudo mkdir -p /etc/kubernetes/authentication')
        ssh.file('/etc/kubernetes/authentication/token-webhook-config.yaml').write(auth_token_webhook_config.to_yaml)

        push_authentication_token_webhook_certs(webhook_config)
      end

      def push_cloud_config
        logger.info { "Pushing cloud-config to master ..." }
        ssh.exec!('sudo mkdir -p /etc/pharos/cloud')
        ssh.file('/etc/pharos/cloud/cloud-config').write(File.open(File.expand_path(@config.cloud.config)))
      end
    end
  end
end
