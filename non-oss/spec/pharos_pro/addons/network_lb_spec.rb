require 'pharos/addon'
require 'pharos_pro/addons/kontena-network-lb/addon'


describe Pharos::Addons::KontenaNetworkLb do
  let(:cluster_config) { Pharos::Config.new(
    hosts: [Pharos::Configuration::Host.new(role: 'worker')],
    network: {},
    addons: {},
    etcd: {}
  ) }
  let(:config) { {} }
  let(:kube_client) { double }
  let(:cpu_arch) { double(:cpu_arch ) }

  subject {
    described_class.new(config, enabled: true, kube_client: kube_client, cpu_arch: cpu_arch, cluster_config: cluster_config)
  }

  describe '#validate' do
    context 'with no peers for BGP address pool' do
      let(:config) {
          {
            enabled: true,
            address_pools: [
              {
                name: 'default',
                protocol: 'bgp',
                addresses: ['147.75.84.224/27']
              }
            ]
          }
       }

      it 'raises' do
        expect { subject.validate }.to raise_error Pharos::InvalidAddonError, "Peers have to be configured for BGP protocol"
      end

    end
  end

end
