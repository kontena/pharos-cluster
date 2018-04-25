require 'pharos/phases/validate_host'

describe Pharos::Phases::ValidateHost do
  let(:config) { Pharos::Config.new(
      hosts: [
        Pharos::Configuration::Host.new(
          address: '192.0.2.1',
        ),
      ],
  ) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(config.hosts[0], config: config, ssh: ssh) }

  describe '#private_interface_address' do
    let(:iface) { 'eth0' }
    before do
      allow(ssh).to receive(:exec!).with(/ip -o addr show/).and_return(ip_addr)
    end

    context "for an interface configured with a private IP" do
      let(:ip_addr) { <<~EOM
        2: eth1    inet 192.168.0.10/24 brd 192.168.0.255 scope global eth0\       valid_lft forever preferred_lft forever
      EOM
      }

      it "returns the private IP" do
        expect(subject.private_interface_address('eth1')).to eq '192.168.0.10'
      end
    end

    context "for an interface that is not configured" do
      let(:ip_addr) { <<~EOM
      EOM
      }

      it "returns nil" do
        expect(subject.private_interface_address('eth1')).to eq nil
      end
    end

    context "with a public and private IP on the same interface" do
      let(:ip_addr) { <<~EOM
        2: eth0    inet 192.0.2.1/24 brd 192.0.2.255 scope global eth0\       valid_lft forever preferred_lft forever
        2: eth0    inet 10.18.0.5/16 brd 10.18.255.255 scope global eth0\       valid_lft forever preferred_lft forever
      EOM
      }

      it "returns the private IP" do
        expect(subject.private_interface_address('eth0')).to eq '10.18.0.5'
      end
    end
  end
end
