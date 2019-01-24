# frozen_string_literal: true

module Pharos
  module Phases
    class PullMasterImages < Pharos::Phase
      title "Pull control plane images"

      def call
        logger.info { "Pulling control plane images ..." }
        cfg = kubeadm.generate_yaml_config
        ssh.tempfile(content: cfg, prefix: "kubeadm.cfg") do |tmp_file|
          ssh.exec!("sudo kubeadm config images pull --config #{tmp_file}")
        end
      end

      def kubeadm
        Pharos::Kubeadm::ConfigGenerator.new(@config, @host)
      end
    end
  end
end
