# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureMaster < Pharos::Phase
      title "Configure master"

      KUBE_DIR = '/etc/kubernetes'
      SHARED_CERT_FILES = %w(ca.crt ca.key sa.key sa.pub).freeze

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end

      def install?
        !@ssh.file("/etc/kubernetes/admin.conf").exist?
      end

      def call
        push_kube_certs(cluster_context['master-certs']) if cluster_context['master-certs']

        logger.info { "Checking if Kubernetes control plane is already initialized ..." }
        if install?
          logger.info { "Kubernetes control plane is not initialized" }
          install
          install_kubeconfig
        else
          reconfigure
        end

        cluster_context['master-certs'] = pull_kube_certs unless cluster_context['master-certs']
      end

      def install
        cfg = kubeadm.generate_config

        logger.info { "Initializing control plane ..." }

        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          exec_script(
            'kubeadm-init.sh',
            TMP_FILE: tmp_file
          )
        end

        logger.info { "Initialization of control plane succeeded!" }
      end

      def install_kubeconfig
        @ssh.exec!('install -m 0700 -d ~/.kube')
        @ssh.exec!('sudo install -o $USER -m 0600 /etc/kubernetes/admin.conf ~/.kube/config')
      end

      def reconfigure
        cfg = kubeadm.generate_config

        logger.info { "Configuring control plane ..." }

        @ssh.tempfile(content: cfg.to_yaml, prefix: "kubeadm.cfg") do |tmp_file|
          exec_script(
            'kubeadm-reconfigure.sh',
            TMP_FILE: tmp_file
          )
        end
      end

      # @param certs [Hash] path => PEM data
      def push_kube_certs(certs)
        @ssh.exec!("sudo mkdir -p #{KUBE_DIR}/pki")
        certs.each do |file, contents|
          path = File.join(KUBE_DIR, 'pki', file)
          @ssh.file(path).write(contents)
          @ssh.exec!("sudo chmod 0400 #{path}")
        end
      end

      # @return [Hash] path => PEM data
      def pull_kube_certs
        certs = {}
        SHARED_CERT_FILES.each do |file|
          path = File.join(KUBE_DIR, 'pki', file)
          certs[file] = @ssh.file(path).read
        end
        certs
      end
    end
  end
end
