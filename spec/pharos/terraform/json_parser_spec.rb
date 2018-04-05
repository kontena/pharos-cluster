require 'pharos/terraform/json_parser'

describe Pharos::Terraform::JsonParser do

  let(:subject) { described_class.new(fixture('tf.json')) }

  describe '#hosts' do
    it 'parses valid terraform json file' do
      hosts = subject.hosts
      expect(hosts.size).to eq(4)
      expect(hosts.select{ |h| h[:role] == 'master' }.size).to eq(1)
      expect(hosts.select{ |h| h[:role] == 'worker' }.size).to eq(3)
      expect(hosts.select{ |h| h[:role] == 'master' }[0][:user]).to eq('root')
      expect(hosts.select{ |h| h[:role] == 'worker' }[0][:user]).to eq('ubuntu')
    end
  end
end