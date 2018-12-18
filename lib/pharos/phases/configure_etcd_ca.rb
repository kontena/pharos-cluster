# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureEtcdCa < Pharos::Phase
      title "Configure etcd certificate authority"
      CA_PATH = '/etc/pharos/pki'
      CA_FILES = %w(ca.pem ca-key.pem).freeze

      def call
        logger.info { 'Configuring etcd certificate authority ...' }
        exec_script(
          'configure-etcd-ca.sh',
          ARCH: @host.cpu_arch.name
        )
        logger.info { 'Caching certificate authority files to memory ...' }
        cache_ca_to_memory
      end

      def cache_ca_to_memory
        data = {}
        CA_FILES.each do |file|
          data[file] = ssh.file(File.join(CA_PATH, file)).read
        end
        cluster_context['etcd-ca'] = data
      end
    end
  end
end
