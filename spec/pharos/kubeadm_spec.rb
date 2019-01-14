require "pharos/phases/configure_master"

describe Pharos::Kubeadm::ConfigGenerator do
  let(:master) { Pharos::Configuration::Host.new(address: 'test', private_address: 'private', role: 'master') }
  let(:config_hosts_count) { 1 }

  let(:config) { Pharos::Config.new(
      hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new(role: 'worker') },
      network: {
        service_cidr: '1.2.3.4/16',
        pod_network_cidr: '10.0.0.0/16'
      },
      addons: {},
      etcd: {}
  ) }

  subject { described_class.new(config, master) }

  describe '#generate_yaml_config' do
    it 'returns full yaml' do
      yaml = subject.generate_yaml_config
      configs = YAML.load_stream(yaml)
      kinds = configs.map { |config| config['kind'] }
      expect(kinds).to eq(%w(InitConfiguration ClusterConfiguration KubeProxyConfiguration KubeletConfiguration))
    end
  end

  describe '#generate_authentication_token_webhook_config' do
    let(:webhook_config) do
      {
        cluster: {
          name: 'pharos-authn',
          server: 'http://localhost:9292/token'
        },
        user: {
          name: 'pharos-apiserver'
        }
      }
    end

    it 'comes with proper configuration' do
      valid_config =  {
        "kind" => "Config",
        "apiVersion" => "v1",
        "preferences" => {},
        "clusters" => [
            {
                "name" => "pharos-authn",
                "cluster" => {
                    "server" => "http://localhost:9292/token",
                }
            }
        ],
        "users" => [
            {
                "name" => "pharos-apiserver",
                "user" => {}
            }
        ],
        "contexts" => [
            {
                "name" => "webhook",
                "context" => {
                    "cluster" => "pharos-authn",
                    "user" => "pharos-apiserver"
                }
            }
        ],
        "current-context" => "webhook"
      }
      expect(subject.generate_authentication_token_webhook_config(webhook_config))
        .to eq(valid_config)
    end

    context 'with cluster certificate_authority' do
      it 'adds certificate authority config' do
        webhook_config[:cluster][:certificate_authority] = '/etc/ca.pem'
        config = subject.generate_authentication_token_webhook_config(webhook_config)
        expect(config['clusters'][0]['cluster']['certificate-authority']).to eq('/etc/pharos/token_webhook/ca.pem')
      end
    end

    context 'with user client certificate' do
      it 'adds client certificate' do
        webhook_config[:user][:client_certificate] = '/etc/cert.pem'
        config = subject.generate_authentication_token_webhook_config(webhook_config)
        expect(config['users'][0]['user']['client-certificate']).to eq('/etc/pharos/token_webhook/cert.pem')
      end
    end

    context 'with user client key' do
      it 'adds client key' do
        webhook_config[:user][:client_key] = '/etc/key.pem'
        config = subject.generate_authentication_token_webhook_config(webhook_config)
        expect(config['users'][0]['user']['client-key']).to eq('/etc/pharos/token_webhook/key.pem')
      end
    end
  end
end
