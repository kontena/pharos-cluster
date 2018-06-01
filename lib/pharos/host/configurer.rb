# frozen_string_literal: true

module Pharos
  module Host
    class Config < ::Dry::Struct
      attribute :name, Pharos::Types::String
      attribute :version, Pharos::Types::String
      attribute :cls, Pharos::Types::Object
    end

    class Configurer
      attr_reader :host, :ssh

      @@configs = []

      def initialize(host, ssh)
        @host = host
        @ssh = ssh
      end

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, self.class.os_name, 'scripts', *path)
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

      class << self
        attr_reader :os_name, :os_version

        def register_component(component)
          Pharos::Phases.register_component component
        end

        def register_config(name, version)
          @os_name = name
          @os_version = version
          config = Pharos::Host::Config.new(name: name, version: version, cls: self)
          @@configs << config
          config
        end

        def supported_os?(os_release)
          @@configs.any? { |config| config.name == os_release.id && config.version == os_release.version }
        end

        def config_for_os_release(os_release)
          @@configs.find { |config| config.name == os_release.id && config.version == os_release.version }
        end

        def configs
          @@configs
        end
      end
    end
  end
end