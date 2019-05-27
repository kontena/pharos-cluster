require 'pharos/terraform/json_parser'

describe Pharos::Terraform::JsonParser do

  let(:subject) { described_class.new(fixture('terraform/tf.json')) }

  describe '#hosts' do
    it 'parses valid terraform json file' do
      hosts = subject.hosts
      expect(hosts.size).to eq(4)
      expect(hosts.select{ |h| h[:role] == 'master' }.size).to eq(1)
      expect(hosts.select{ |h| h[:role] == 'worker' }.size).to eq(3)
      master = hosts.select{ |h| h[:role] == 'master' }.first
      worker = hosts.select{ |h| h[:role] == 'worker' }.first
      expect(master[:user]).to eq('root')
      expect(worker[:user]).to eq('ubuntu')
      expect(worker[:environment]).to eq({ 'BAR' => 'baz' })
    end

    it 'raises error on invalid json' do
      subject = described_class.new('{"asdsds": "asdsdasd"')
      expect {
        subject.hosts
      }.to raise_error(described_class::ParserError)
    end
  end

  describe '#addons' do
    let(:subject) { described_class.new(fixture('terraform/with_addons.json')) }

    it 'parses valid terraform json file' do
      addons = subject.addons
      expect(addons.keys.size).to eq(1)
      expect(addons['addon1']).to eq({ "foo" => "bar", "bar" => "baz" })
    end

    it 'returns empty hash if no addons are defined' do
      subject = described_class.new(fixture('terraform/tf.json'))
      expect(subject.addons).to eq({})
    end
  end
end
