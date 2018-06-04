# frozen_string_literal: true

module Pharos
  module Host
    class CoreOS < Configurer
      register_config 'coreos', 'stable'

      # @param [Pharos::Configuration::OsRelease]
      # @return [Boolean]
      def self.supported_os?(os_release)
        os_name == os_release.id
      end

      # @return [String]
      def script_library_install_path
        "/opt/pharos"
      end

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, 'scripts', *path)
      end

      def install_essentials
        exec_script(
          'configure-essentials.sh',
          HTTP_PROXY: host.http_proxy.to_s,
          SET_HTTP_PROXY: host.http_proxy.nil? ? 'false' : 'true'
        )
      end

      def configure_repos; end

      def configure_netfilter
        exec_script('configure-netfilter.sh')
      end

      def configure_cfssl
        exec_script(
          'configure-cfssl.sh',
          ARCH: host.cpu_arch.name
        )
      end

      def configure_container_runtime
        raise Pharos::Error, "Unknown container runtime: #{host.container_runtime}" unless docker?
        exec_script(
          'configure-docker.sh'
        )
      end

      def ensure_kubelet(args)
        exec_script(
          'ensure-kubelet.sh',
          args
        )
      end

      def install_kubelet(args)
        exec_script(
          'install-kubelet.sh',
          args
        )
      end
    end
  end
end
