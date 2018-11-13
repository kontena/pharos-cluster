# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMaster < Pharos::Phase
      title "Configure master"

      KUBE_DIR = '/etc/kubernetes'
      SHARED_CERT_FILES = %w(ca.crt ca.key sa.key sa.pub front-proxy-ca.key front-proxy-ca.crt).freeze
      APISERVER_CERT = '/etc/kubernetes/pki/apiserver.crt'
      APISERVER_KEY = '/etc/kubernetes/pki/apiserver.key'

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def install?
        !ssh.file("/etc/kubernetes/admin.conf").exist?
      end

      def call
        push_kube_certs(cluster_context['master-certs']) if cluster_context['master-certs']

        logger.info { "Checking if Kubernetes control plane is already initialized ..." }
        if install?
          logger.info { "Kubernetes control plane is not initialized." }
          install
          install_kubeconfig
        elsif !cluster_context['api_upgraded']
          reconfigure
        else
          logger.info { "Kubernetes control plane is up to date." }
        end

        cluster_context['master-certs'] = pull_kube_certs unless cluster_context['master-certs']
      end

      def install
        cfg = kubeadm.generate_config

        logger.info { "Initializing control plane (v#{Pharos::KUBE_VERSION}) ..." }
        logger.debug { cfg.to_yaml }

        ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          exec_script(
            'kubeadm-init.sh',
            CONFIG: tmp_file
          )
        end

        logger.info { "Initialization of control plane succeeded!" }
      end

      def install_kubeconfig
        ssh.exec!('install -m 0700 -d ~/.kube')
        ssh.exec!('sudo install -o $USER -m 0600 /etc/kubernetes/admin.conf ~/.kube/config')
      end

      def reconfigure
        replace_cert if replace_cert?

        cfg = kubeadm.generate_config

        logger.info { "Reconfiguring control plane (v#{Pharos::KUBE_VERSION})..." }
        logger.debug { cfg.to_yaml }

        ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          exec_script(
            'kubeadm-reconfigure.sh',
            CONFIG: tmp_file
          )
        end
      end

      # @param certs [Hash] path => PEM data
      def push_kube_certs(certs)
        ssh.exec!("sudo mkdir -p #{KUBE_DIR}/pki")
        certs.each do |file, contents|
          path = File.join(KUBE_DIR, 'pki', file)
          ssh.file(path).write(contents)
          ssh.exec!("sudo chmod 0400 #{path}")
        end
      end

      # @return [Hash] path => PEM data
      def pull_kube_certs
        certs = {}
        SHARED_CERT_FILES.each do |file|
          path = File.join(KUBE_DIR, 'pki', file)
          certs[file] = ssh.file(path).read
        end
        certs
      end

      # @param path [String]
      # @return [OpenSSL::X509::Certificate, nil] nil if not exist
      def read_cert(path)
        file = ssh.file(path)

        return nil unless file.exist?

        OpenSSL::X509::Certificate.new file.read
      end

      # @param cert [OpenSSL::X509::Certificate]
      # @return [Array<String>]
      def read_cert_sans(cert)
        sans = nil

        cert.extensions.each do |ext|
          sans = ext.value if ext.oid == 'subjectAltName'
        end

        return [] unless sans

        sans.split(',').map{ |san|
          prefix, name = san.strip.split(':', 2)

          case prefix
          when 'DNS'
            name
          when 'IP Address'
            name
          else
            logger.warn { "Unknown SAN in cert: #{san}" }
            nil
          end
        }.compact
      end

      # @return [Boolean]
      def replace_cert?
        cert = read_cert(APISERVER_CERT)

        if !cert
          logger.debug { "apiserver cert does not yet exist, kubeadm will create it" }
          return false
        end

        sans = read_cert_sans(cert)

        missing_sans = kubeadm.build_extra_sans - sans
        extra_sans = sans - kubeadm.build_extra_sans

        if missing_sans.empty?
          logger.debug { "apiserver cert is up to update: #{sans}" }
          return false
        else
          logger.debug { "apiserver cert is missing SANs: #{missing_sans} (extra: #{extra_sans})" }
          return true
        end
      end

      def replace_cert
        logger.info { "Replacing apiserver cert" }

        ssh.file(APISERVER_CERT).rm
        ssh.file(APISERVER_KEY).rm
      end
    end
  end
end
