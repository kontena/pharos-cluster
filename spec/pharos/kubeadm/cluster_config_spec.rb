require "pharos/phases/configure_master"

describe Pharos::Kubeadm::ClusterConfig do
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

  describe '#generate' do

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
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'audit-webhook-config-file')).to eq('/etc/pharos/audit/webhook.yml')
        expect(config.dig('apiServer', 'extraVolumes')).to include({
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
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'audit-log-path')).to eq('/var/log/kube_audit/audit.json')
        expect(config.dig('apiServer', 'extraArgs', 'audit-log-maxage')).to eq('30')
        expect(config.dig('apiServer', 'extraArgs', 'audit-log-maxbackup')).to eq('10')
        expect(config.dig('apiServer', 'extraArgs', 'audit-log-maxsize')).to eq('200')
        expect(config.dig('apiServer', 'extraVolumes')).to include({
          'name' => 'k8s-audit-file',
          'hostPath' => '/var/log/kube_audit',
          'mountPath' => '/var/log/kube_audit',
          'readOnly' => false
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
        config = subject.generate
        expect(config.dig('networking', 'serviceSubnet')).to eq('1.2.3.4/16')
        expect(config.dig('networking', 'podSubnet')).to eq('10.0.0.0/16')
      end

    end

    it 'comes with correct master addresses' do
      config.hosts << master
      config = subject.generate
      expect(config.dig('apiServer', 'certSANs')).to eq(['localhost', 'test', 'private'])
    end

    it 'comes with internal etcd config' do
      config = subject.generate
      expect(config.dig('etcd', 'external')).not_to be_nil
      expect(config.dig('etcd', 'external', 'endpoints')).not_to be_nil
      expect(config.dig('etcd', 'external', 'version')).to be_nil
    end

    it 'comes with secrets encryption config' do
      config = subject.generate
      expect(config.dig('apiServer', 'extraArgs', 'experimental-encryption-provider-config')).to eq(described_class::SECRETS_CFG_FILE)
      expect(config.dig('apiServer', 'extraVolumes')).to include({'name' => 'k8s-secrets-config',
        'hostPath' => described_class::SECRETS_CFG_DIR,
        'mountPath' => described_class::SECRETS_CFG_DIR
      })
    end

    context 'with internal etcd configuration' do
      let(:config) {
        Pharos::Config.new(
          hosts: (1..3).map { |i| Pharos::Configuration::Host.new(
            address: "10.10.0.#{i}", role: "master"
          ) },
          network: {},
          addons: {}
        )
      }
      subject { described_class.new(config, config.hosts.last) }

      it 'sets etcd to localhost by default' do
        config = subject.generate
        expect(config.dig('etcd', 'external', 'endpoints')).to eq([
          'https://localhost:2379', 'https://10.10.0.1:2379', 'https://10.10.0.2:2379',
        ])
      end
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
        config = subject.generate
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
        config = subject.generate
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
        config = subject.generate
        expect(config.dig('apiServer', 'extraVolumes')).to include(pharos_volume_mount)
        expect(config.dig('controllerManager', 'extraVolumes')).to include(pharos_volume_mount)
      end
    end

    context 'with in-tree cloud provider' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        cloud: {
          provider: 'aws'
        }
      ) }

      it 'comes with proper cloud provider' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'cloud-provider')).to eq('aws')
      end

      it 'comes with proper cloud config' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'cloud-config')).to be_nil
        expect(config.dig('controllerManager', 'extraArgs', 'cloud-config')).to be_nil
      end
    end

    context 'with in-tree cloud configuration' do
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
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'cloud-provider')).to eq('aws')
      end

      it 'comes with proper cloud config' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'cloud-config')).to eq('/etc/pharos/cloud/cloud-config')
        expect(config.dig('controllerManager', 'extraArgs', 'cloud-config')).to eq('/etc/pharos/cloud/cloud-config')
      end
    end

    context 'with out-tree cloud provider' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        cloud: {
          provider: 'hcloud'
        }
      ) }

      it 'does not' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'cloud-provider')).to be_nil
      end

      it 'comes with proper feature gates' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'feature-gates')).not_to be_nil
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
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'authentication-token-webhook-config-file'))
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
        config = subject.generate
        expect(config.dig('apiServer', 'extraVolumes')).to include(valid_volume_mounts[0])
      end
    end

    context 'with authentication oidc configuration' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        addons: {},
        authentication: {
          oidc: {
            issuer_url: "https://accounts.google.com",
            client_id: "foobar",
            username_claim: 'email',
            ca_file: '/path/to/oidc.ca.crt'
          }
        }
      ) }

      it 'comes with proper oidc flags for api-server' do
        config = subject.generate
        expect(config.dig('apiServer', 'extraArgs', 'oidc-issuer-url'))
          .to eq('https://accounts.google.com')
          expect(config.dig('apiServer', 'extraArgs', 'oidc-client-id'))
          .to eq('foobar')
          expect(config.dig('apiServer', 'extraArgs', 'oidc-username-claim'))
          .to eq('email')
      end

      it 'comes with proper volume mounts' do
        valid_volume_mounts =  [
          {
            'name' => 'k8s-auth-oidc',
            'hostPath' => '/etc/kubernetes/authentication',
            'mountPath' => '/etc/kubernetes/authentication'
          }
        ]
        config = subject.generate
        expect(config.dig('apiServer', 'extraVolumes')).to include(valid_volume_mounts[0])
        expect(config.dig('apiServer', 'extraArgs', 'oidc-ca-file'))
          .to eq('/etc/kubernetes/authentication/oidc_ca.crt')
      end
    end

    context 'with control plane feature gates' do
      let(:config) { Pharos::Config.new(
        hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
        network: {},
        control_plane: {
          feature_gates: {
            foo: true
          }
        }
      ) }

      it 'adds feature gates in apiServer extraArgs' do
        extra_args = subject.generate.dig('apiServer','extraArgs')
        expect(extra_args['feature-gates']).to eq('foo=true')
      end

      it 'adds feature gates in scheduler extraArgs' do
        extra_args = subject.generate.dig('scheduler','extraArgs')
        expect(extra_args['feature-gates']).to eq('foo=true')
      end

      it 'adds feature gates in controllerManager extraArgs' do
        extra_args = subject.generate.dig('controllerManager','extraArgs')
        expect(extra_args['feature-gates']).to eq('foo=true')
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
          extra_args = subject.generate['apiServer']['extraArgs']
          expect(extra_args['enable-admission-plugins']).to eq('PodSecurityPolicy,NodeRestriction,AlwaysPullImages,NamespaceLifecycle,ServiceAccount')
          expect(extra_args['disable-admission-plugins']).to eq('Priority')
        end
      end

      context 'without config' do
        let(:config) { Pharos::Config.new(
          hosts: (1..config_hosts_count).map { |i| Pharos::Configuration::Host.new() },
          network: {}
        ) }

        it 'configures default plugins to api server' do
          extra_args = subject.generate['apiServer']['extraArgs']
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
          extra_args = subject.generate['apiServer']['extraArgs']
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
          extra_args = subject.generate['apiServer']['extraArgs']
          expect(extra_args['enable-admission-plugins']).to eq('PodSecurityPolicy,NodeRestriction,AlwaysPullImages,NamespaceLifecycle,ServiceAccount')
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
          extra_args = subject.generate['apiServer']['extraArgs']
          expect(extra_args['disable-admission-plugins']).to eq('PodSecurityPolicy,AlwaysPullImages')
          expect(extra_args.has_key?('enable-admission-plugins')).to be_truthy
          expect(extra_args['enable-admission-plugins']).to eq('NodeRestriction,NamespaceLifecycle,ServiceAccount')
        end
      end
    end
  end
end
