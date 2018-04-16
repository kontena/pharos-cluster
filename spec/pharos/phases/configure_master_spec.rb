require "pharos/phases/configure_master"

describe Pharos::Phases::ConfigureMaster do
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

  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(master, config: config, ssh: ssh) }

  describe '#generate_config' do

    context 'with auth configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        audit: {
          server: 'foobar'
        }
      ) }

      it 'comes with proper audit config' do
        config = subject.generate_config
        expect(config.dig('apiServerExtraArgs', 'audit-webhook-config-file')).to eq('/etc/pharos/audit/webhook.yml')
        expect(config.dig('apiServerExtraVolumes')).to include({
          'name' => 'k8s-audit-webhook',
          'hostPath' => '/etc/pharos/audit',
          'mountPath' => '/etc/pharos/audit'
        })
      end
    end

    context 'with network configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {
          service_cidr: '1.2.3.4/16',
          pod_network_cidr: '10.0.0.0/16'
        },
        addons: {},
        etcd: {}
      ) }

      it 'comes with correct subnets' do
        config = subject.generate_config
        expect(config.dig('networking', 'serviceSubnet')).to eq('1.2.3.4/16')
        expect(config.dig('networking', 'podSubnet')).to eq('10.0.0.0/16')
      end

    end

    it 'comes with correct master addresses' do
      config.hosts << master
      config = subject.generate_config
      expect(config.dig('apiServerCertSANs')).to eq(['localhost', 'test', 'private'])
      expect(config.dig('api', 'advertiseAddress')).to eq('private')
    end

    it 'comes with internal etcd config' do
      config = subject.generate_config
      expect(config.dig('etcd')).not_to be_nil
      expect(config.dig('etcd', 'endpoints')).not_to be_nil
      expect(config.dig('etcd', 'version')).to be_nil
    end

    context 'with etcd endpoint configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {
          endpoints: ['ep1', 'ep2']
        }
      ) }

      it 'comes with proper etcd endpoint config' do
        config = subject.generate_config
        expect(config.dig('etcd', 'endpoints')).to eq(['ep1', 'ep2'])
      end
    end

    context 'with etcd certificate configuration' do

      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {
          endpoints: ['ep1', 'ep2'],
          ca_certificate: 'ca-certificate.pem',
          certificate: 'certificate.pem',
          key: 'key.pem'
        }
      ) }

      it 'comes with proper etcd certificate config' do
        config = subject.generate_config
        expect(config.dig('etcd', 'caFile')).to eq('/etc/pharos/etcd/ca-certificate.pem')
        expect(config.dig('etcd', 'certFile')).to eq('/etc/pharos/etcd/certificate.pem')
        expect(config.dig('etcd', 'keyFile')).to eq('/etc/pharos/etcd/certificate-key.pem')
      end
    end

    context 'with authentication webhook configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        authentication: {
          token_webhook: {
            config: {
              cluster: {
                name: 'pharos-authn',
                server: 'http://localhost:9292/token'
              },
              user: {
                name: 'pharos-apiserver'
              }
            }
          }
        }
      ) }

      it 'comes with proper authentication webhook token config' do
        config = subject.generate_config
        expect(config['apiServerExtraArgs']['authentication-token-webhook-config-file'])
          .to eq('/etc/kubernetes/authentication/token-webhook-config.yaml')
      end

      it 'comes with proper volumen mounts' do
        valid_volume_mounts =  [
          {
            'name' => 'k8s-auth-token-webhook',
            'hostPath' => '/etc/kubernetes/authentication',
            'mountPath' => '/etc/kubernetes/authentication'
          },
          {
            'name' => 'pharos',
            'hostPath' => '/etc/pharos',
            'mountPath' => '/etc/pharos'
          }
        ]
        config = subject.generate_config
        expect(config['apiServerExtraVolumes']).to eq(valid_volume_mounts)
      end
    end

    context 'with cri-o configuration' do
      let(:master) { Pharos::Configuration::Host.new(address: 'test', container_runtime: 'cri-o') }
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        etcd: {}
      ) }

      it 'comes with proper etcd endpoint config' do
        config = subject.generate_config
        expect(config.dig('criSocket')).to eq('/var/run/crio/crio.sock')
      end
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
