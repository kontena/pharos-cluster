# frozen_string_literal: true

require_relative 'base'

module Pharos
  module Phases
    class ConfigureClusterInfo < Base
      # @param master [Pharos::Configuration::Host]
      def initialize(master)
        @master = master
      end

      def client
        @client ||= Pharos::Kube.client(@master.address)
      end

      def call
        logger.info { "Updating public cluster-info ..." }
        configmap = client.get_config_map('cluster-info', 'kube-public')
        kubeconfig = YAML.safe_load(configmap.data['kubeconfig'])
        kubeconfig['clusters'][0]['cluster']['server'] = 'https://127.0.0.1:6443'
        configmap.data['kubeconfig'] = YAML.dump(kubeconfig)
        client.update_config_map(configmap)
      end
    end
  end
end
