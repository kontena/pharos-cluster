# frozen_string_literal: true

module Pharos
  module Phases
    class PullMasterImages < Pharos::Phase
      title "Pull control plane images"

      on :master_hosts

      def call
        logger.info { "Pulling control plane images ..." }
        cfg = kubeadm.generate_yaml_config
        transport.tempfile(content: cfg, prefix: "kubeadm.cfg") do |tmp_file|
          transport.exec!("sudo kubeadm config images pull --config #{tmp_file}")
        end
      end

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end
    end
  end
end
