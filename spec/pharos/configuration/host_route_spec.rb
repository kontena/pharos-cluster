require 'pharos/config'

describe Pharos::Configuration::Route do
  describe '#self.parse' do
    {
      'default via 192.0.2.1 dev eth0 onlink' => {prefix: 'default', via: '192.0.2.1', dev: 'eth0', options: 'onlink'},
      '10.18.0.0/16 dev eth0  proto kernel  scope link  src 10.18.0.13' => {prefix: '10.18.0.0/16', dev: 'eth0', proto: 'kernel', options: 'scope link  src 10.18.0.13'},
      'blackhole 10.32.0.0/24  proto bird' => {type: 'blackhole', prefix: '10.32.0.0/24', proto: 'bird'},
      '10.32.0.39 dev cali5f1ddd73716  scope link' => {prefix: '10.32.0.39', dev: 'cali5f1ddd73716', options: 'scope link'},
      '10.32.1.0/24 via 192.0.2.10 dev tunl0  proto bird onlink' => {prefix: '10.32.1.0/24', via: '192.0.2.10', dev: 'tunl0', proto: 'bird', options: 'onlink'},
      '192.0.2.0/24 dev eth0  proto kernel  scope link  src 192.0.2.11' => {prefix: '192.0.2.0/24', dev: 'eth0', proto: 'kernel', options: 'scope link  src 192.0.2.11'},
      '172.17.0.0/16 dev docker0  proto kernel  scope link  src 172.17.0.1 linkdown' => {prefix: '172.17.0.0/16', dev: 'docker0', proto: 'kernel', options: 'scope link  src 172.17.0.1 linkdown'},
    }.each do |line, attrs|
      it "parses: #{line}" do
        expect(described_class.parse(line).to_hash).to eq described_class.new(raw: line, **attrs).to_hash
      end
    end
  end

  describe '#overlaps?' do
    context 'for a default route' do
      subject do
        described_class.new(prefix: 'default')
      end

      it 'does not overlay with anything' do
        expect(subject.overlaps? '192.0.2.1').to be_falsey
      end
    end

    context 'for a /24 route' do
      subject do
        described_class.new(prefix: '192.0.2.0/24')
      end

      it 'overlaps with an IP within the subnet' do
        expect(subject.overlaps? '192.0.2.1').to be_truthy
      end

      it 'overlaps with a sub-subnet' do
        expect(subject.overlaps? '192.0.2.128/30').to be_truthy
      end

      it 'does not overlap with an adjacent IP' do
        expect(subject.overlaps? '192.0.3.1').to be_falsey
      end

      it 'does not overlap with an adjacent subnet' do
        expect(subject.overlaps? '192.0.3.0/24').to be_falsey
      end

      it 'overlaps with a super-net' do
        expect(subject.overlaps? '192.0.0.0/16').to be_truthy
      end
    end
  end
end
