# frozen_string_literal: true

module Pharos
  class KubeconfigCommand < Pharos::Command
    options :load_config, :tf_json

    option ['-n', '--name'], 'NAME', 'cluster name', attribute_name: :cluster_name, default: 'pharos-cluster'
    option ['-C', '--context'], 'CONTEXT', 'context name', attribute_name: :context_name
    option ['-u', '--user'], 'USER', 'user name', attribute_name: :user_name, default: 'pharos-admin'
    option ['-m', '--merge'], '[FILE]', 'merge with existing configuration file', multivalued: true

    REMOTE_FILE = "/etc/kubernetes/admin.conf"

    def execute
      Dir.chdir(config_yaml.dirname) do
        transport.connect

        config = Pharos::Kube::Config.new
        config.config['clusters'] << {
          'cluster' => {
            'certificate-authority-data' => certificate_authority_data,
            'server' => "https://#{master_host.api_address}:6443"
          },
          'name' => cluster_name
        }

        config.config['users'] << {
          'user' => {
            'token' => create_or_update_sa_token
          },
          'name' => user_name
        }

        config.config['contexts'] << {
          'context' => {
            'cluster' => cluster_name,
            'user' => 'pharos-admin'
          },
          'name' => context_name || "#{user_name}@#{cluster_name}"
        }

        config.config['current-context'] = context_name || "#{user_name}@#{cluster_name}"

        merge_list.each do |merge|
          merge_config = Pharos::Kube::Config.new(File.read(merge))
          config << merge_config
        end
        puts config
      end
    end

    private

    # @return token [String]
    def create_or_update_sa_token
      transport.exec!("kubectl get -n kube-system serviceaccount/#{user_name} || kubectl -n kube-system create serviceaccount #{user_name}")
      transport.exec!("kubectl get clusterrolebinding pharos-cluster-admin || kubectl create clusterrolebinding pharos-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:#{user_name}")
      token_name = transport.exec!("kubectl -n kube-system get serviceaccount/#{user_name} -o jsonpath='{.secrets[0].name}'")
      transport.exec!("kubectl -n kube-system get secret #{token_name} -o jsonpath='{.data.token}' | base64 -d")
    end

    def certificate_authority_data
      transport.exec!("kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}'")
    end

    def master_host
      @master_host ||= load_config.master_host
    end

    # @return [Pharos::Config]
    def transport
      @transport ||= master_host.transport
    end
  end
end
