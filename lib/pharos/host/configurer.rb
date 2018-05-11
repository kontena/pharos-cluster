# frozen_string_literal: true

module Pharos
  module Host
    class Configurer
      attr_reader :host, :ssh

      def initialize(host, ssh)
        @host = host
        @ssh = ssh
      end

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, '..', 'scripts', self.class.name_to_underscore, *path)
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        @ssh.exec_script!(
          script,
          env: vars,
          path: script_path(script)
        )
      end

      def crio?
        @host.container_runtime == 'cri-o'
      end

      def docker?
        @host.container_runtime == 'docker'
      end

      def self.register_component(component)
        Pharos::Phases.register_component component
      end

      def self.name_to_underscore
        name_without_namespace = name.split("::").last
        name_without_namespace.gsub(/([^\^])([A-Z])/,'\1_\2').downcase
      end
    end
  end
end