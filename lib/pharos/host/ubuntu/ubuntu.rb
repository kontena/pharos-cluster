# frozen_string_literal: true

module Pharos
  module Host
    class Ubuntu < Configurer
      def install_essentials
        exec_script(
          'configure-essentials.sh',
          HTTP_PROXY: host.http_proxy.to_s,
          SET_HTTP_PROXY: host.http_proxy.nil? ? 'false' : 'true'
        )
      end

      def configure_repos
        exec_script('repos/cri-o.sh') if crio?
        exec_script('repos/kube.sh')
        exec_script('repos/update.sh')
      end

      def configure_netfilter
        exec_script('configure-netfilter.sh')
      end

      def configure_cfssl
        exec_script(
          'configure-cfssl.sh',
          ARCH: host.cpu_arch.name
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
