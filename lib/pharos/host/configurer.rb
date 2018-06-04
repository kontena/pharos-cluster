# frozen_string_literal: true

module Pharos
  module Host
    class Configurer
      attr_reader :host, :ssh

      SCRIPT_LIBRARY = File.join(__dir__, '..', 'scripts', 'pharos.sh').freeze

      def initialize(host, ssh)
        @host = host
        @ssh = ssh
      end

      def install_essentials
        abstract_method!
      end

      def configure_repos
        abstract_method!
      end

      def configure_netfilter
        abstract_method!
      end

      def configure_cfssl
        abstract_method!
      end

      def ensure_kubelet
        abstract_method!
      end

      def install_kubelet
        abstract_method!
      end

      def configure_container_runtime
        abstract_method!
      end

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, self.class.os_name, 'scripts', *path)
      end

      # @return [String]
      def script_library_install_path
        "/usr/local/share/pharos"
      end

      def configure_script_library
        @ssh.exec("sudo mkdir -p #{script_library_install_path}")
        @ssh.file("#{script_library_install_path}/util.sh").write(
          File.read(SCRIPT_LIBRARY)
        )
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
          configs << self
          self
        end

        # @param [Pharos::Configuration::OsRelease]
        # @return [Boolean]
        def supported_os?(os_release)
          os_name == os_release.id && os_version == os_release.version
        end

        # @param [Pharos::Configuration::OsRelease]
        # @return [Class<Configurer>, NilClass]
        def config_for_os_release(os_release)
          configs.find { |config| config.supported_os?(os_release) }
        end

        def configs
          @@configs ||= [] # rubocop:disable Style/ClassVars
        end
      end

      private

      def abstract_method!
        raise NotImplementedError, 'This is an abstract base method. Implement in your subclass.'
      end
    end
  end
end
