require 'pharos/terraform/json_parser'

describe Pharos::Terraform::JsonParser do

  let(:subject) do
    described_class.new({
      pharos_cluster: {
        value: {
          hosts: [],
          addons: {}
        },
        type: ['tuple', {}]
      }
    }.to_json)
  end

  describe '#valid?' do
    it 'returns true with valid json' do
      expect(subject.valid?).to be_truthy
    end

    it 'returns false with legacy json' do
      subject = described_class.new({
        pharos_cluster: {
          value: {
            hosts: [],
            addons: {}
          },
          type: 'tuple'
        }
      }.to_json)
      expect(subject.valid?).to be_falsey
    end
  end

  describe '#cluster' do
    it 'returns the value without mangling' do
      expect(subject.cluster.keys).to eq(%w(hosts addons))
    end
  end
end
