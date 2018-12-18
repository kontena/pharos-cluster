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

  describe '#generate_config' do

    context 'with webhook audit configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        audit: {
          webhook: {
            server: 'foobar'
          }
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

    context 'with file audit configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        audit: {
          file: {
            path: '/var/log/kube_audit/audit.json',
            max_age: 30,
            max_backups: 10,
            max_size: 200
          }
        }
      ) }

      it 'comes with proper audit config' do
        config = subject.generate_config
        expect(config.dig('apiServerExtraArgs', 'audit-log-path')).to eq('/var/log/kube_audit/audit.json')
        expect(config.dig('apiServerExtraArgs', 'audit-log-maxage')).to eq('30')
        expect(config.dig('apiServerExtraArgs', 'audit-log-maxbackup')).to eq('10')
        expect(config.dig('apiServerExtraArgs', 'audit-log-maxsize')).to eq('200')
        expect(config.dig('apiServerExtraVolumes')).to include({
          'name' => 'k8s-audit-file',
          'hostPath' => '/var/log/kube_audit',
          'mountPath' => '/var/log/kube_audit',
          'writable' => true
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
      expect(config.dig('etcd', 'external')).not_to be_nil
      expect(config.dig('etcd', 'external', 'endpoints')).not_to be_nil
      expect(config.dig('etcd', 'external', 'version')).to be_nil
    end

    it 'comes with secrets encryption config' do
      config = subject.generate_config
      expect(config.dig('apiServerExtraArgs', 'experimental-encryption-provider-config')).to eq(described_class::SECRETS_CFG_FILE)
      expect(config['apiServerExtraVolumes']).to include({'name' => 'k8s-secrets-config',
        'hostPath' => described_class::SECRETS_CFG_DIR,
        'mountPath' => described_class::SECRETS_CFG_DIR
      })
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
        expect(config.dig('etcd', 'external', 'endpoints')).to eq(['ep1', 'ep2'])
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
        expect(config.dig('etcd', 'external', 'caFile')).to eq('/etc/pharos/etcd/ca-certificate.pem')
        expect(config.dig('etcd', 'external', 'certFile')).to eq('/etc/pharos/etcd/certificate.pem')
        expect(config.dig('etcd', 'external', 'keyFile')).to eq('/etc/pharos/etcd/certificate-key.pem')
      end

      it 'mounts pharos dir from host' do
        pharos_volume_mount = {
            'name' => 'pharos',
            'hostPath' => '/etc/pharos',
            'mountPath' => '/etc/pharos'
        }
        config = subject.generate_config
        expect(config['apiServerExtraVolumes']).to include(pharos_volume_mount)
        expect(config['controllerManagerExtraVolumes']).to include(pharos_volume_mount)
      end
    end

    context 'with cloud provider' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        cloud: {
          provider: 'aws'
        }
      ) }

      it 'comes with proper cloud provider' do
        config = subject.generate_config
        expect(config['apiServerExtraArgs']['cloud-provider']).to eq('aws')
      end

      it 'comes with proper cloud config' do
        config = subject.generate_config
        expect(config.dig('apiServerExtraArgs', 'cloud-config')).to be_nil
        expect(config.dig('controllerManagerExtraArgs', 'cloud-config')).to be_nil
      end
    end

    context 'with cloud configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        cloud: {
          provider: 'aws',
          config: './cloud-config'
        }
      ) }

      it 'comes with proper cloud provider' do
        config = subject.generate_config
        expect(config['apiServerExtraArgs']['cloud-provider']).to eq('aws')
      end

      it 'comes with proper cloud config' do
        config = subject.generate_config
        expect(config.dig('apiServerExtraArgs', 'cloud-config')).to eq('/etc/pharos/cloud/cloud-config')
        expect(config.dig('controllerManagerExtraArgs', 'cloud-config')).to eq('/etc/pharos/cloud/cloud-config')
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

      it 'comes with proper volume mounts' do
        valid_volume_mounts =  [
          {
            'name' => 'k8s-auth-token-webhook',
            'hostPath' => '/etc/kubernetes/authentication',
            'mountPath' => '/etc/kubernetes/authentication'
          }
        ]
        config = subject.generate_config
        expect(config['apiServerExtraVolumes']).to include(valid_volume_mounts[0])
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
        expect(config.dig('nodeRegistration', 'criSocket')).to eq('/var/run/crio/crio.sock')
      end
    end

    context 'with kube-proxy ipvs configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kube_proxy: {
          mode: 'ipvs',
        }
      ) }

      it 'configures kube-proxy' do
        config = subject.generate_config
        expect(config.dig('kubeProxy', 'config')).to eq(
          'mode' => 'ipvs',
        )
      end
    end

    context 'with kube-proxy iptables configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        kube_proxy: {
          mode: 'iptables',
        }
      ) }

      it 'configures kube-proxy' do
        config = subject.generate_config
        expect(config.dig('kubeProxy', 'config')).to eq(
          'mode' => 'iptables',
        )
      end
    end

    context 'with admission plugins' do
      context 'with proper config' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {},
          admission_plugins: [
            {name: 'PodSecurityPolicy'}, # enabled defaults to true
            {name: 'Priority', enabled: false},
            {name: 'AlwaysPullImages', enabled: true}
          ]
        ) }

        it 'configures enabled plugins to api server' do
          extra_args = subject.generate_config['apiServerExtraArgs']
          expect(extra_args['enable-admission-plugins']).to eq('PodSecurityPolicy,NodeRestriction,AlwaysPullImages')
          expect(extra_args['disable-admission-plugins']).to eq('Priority')
        end
      end

      context 'without config' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {}
        ) }

        it 'configures default plugins to api server' do
          extra_args = subject.generate_config['apiServerExtraArgs']
          expect(extra_args.has_key?('enable-admission-plugins')).to be_truthy
          plugins = extra_args['enable-admission-plugins'].split(',')
          expect(plugins).to include('PodSecurityPolicy')
          expect(plugins).to include('NodeRestriction')
          expect(extra_args.has_key?('disable-admission-plugins')).to be_falsey
        end
      end

      context 'with empty config' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {},
          admission_plugins: []
        ) }

        it 'configures default plugins to api server' do
          extra_args = subject.generate_config['apiServerExtraArgs']
          expect(extra_args.has_key?('enable-admission-plugins')).to be_truthy
          plugins = extra_args['enable-admission-plugins'].split(',')
          expect(plugins).to include('PodSecurityPolicy')
          expect(plugins).to include('NodeRestriction')
          expect(extra_args.has_key?('disable-admission-plugins')).to be_falsey
        end
      end

      context 'with only enabled plugins' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {},
          admission_plugins: [
            {name: 'PodSecurityPolicy'},
            {name: 'AlwaysPullImages', enabled: true}
          ]
        ) }

        it 'configures enabled plugins to api server' do
          extra_args = subject.generate_config['apiServerExtraArgs']
          expect(extra_args['enable-admission-plugins']).to eq('PodSecurityPolicy,NodeRestriction,AlwaysPullImages')
          expect(extra_args.has_key?('disable-admission-plugins')).to be_falsey
        end
      end

      context 'with only disabled plugins' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {},
          admission_plugins: [
            {name: 'PodSecurityPolicy', enabled: false},
            {name: 'AlwaysPullImages', enabled: false}
          ]
        ) }

        it 'configures correct plugins to api server' do
          extra_args = subject.generate_config['apiServerExtraArgs']
          expect(extra_args['disable-admission-plugins']).to eq('PodSecurityPolicy,AlwaysPullImages')
          expect(extra_args.has_key?('enable-admission-plugins')).to be_truthy
          expect(extra_args['enable-admission-plugins']).to eq('NodeRestriction')
        end
      end
    end

    describe 'nodeRegistration.taints' do
      it 'taints the master by default' do
        expect(subject.generate_config['nodeRegistration']['taints']).to be nil
      end

      context 'with empty host taints' do
        let(:master) { Pharos::Configuration::Host.new(
          address: 'test',
          private_address: 'private',
          role: 'master',
          taints: [],
        ) }

        it 'does not taint the master' do
          expect(subject.generate_config['nodeRegistration']['taints']).to eq []
        end
      end

      context 'with master taint' do
        let(:master) { Pharos::Configuration::Host.new(
          address: 'test',
          private_address: 'private',
          role: 'master',
          taints: [
            Pharos::Configuration::Taint.new(key: 'node-role.kubernetes.io/master', effect: 'NoSchedule'),
            Pharos::Configuration::Taint.new(key: 'test', effect: 'NoSchedule'),
          ],
        ) }

        it 'does taint the master' do
          expect(subject.generate_config['nodeRegistration']['taints']).to be nil
        end
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
