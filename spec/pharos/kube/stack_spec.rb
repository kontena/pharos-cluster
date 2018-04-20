describe Pharos::Kube::Stack do
  let(:session) { instance_double(Pharos::Kube::Session) }
  let(:client) { instance_double(Pharos::Kube::Client) }
  subject { described_class.new(session, 'ingress-nginx') }

  before do
    allow(session).to receive(:client).and_return(client)
  end

  let(:vars) { { default_backend: double(image: 'foo'), configmap: {}, node_selector: {}, arch: double(name: 'foo'), version: '1', image: 'foo'} }

  describe '#resource_files' do
    it 'returns a list of .yml and .yml.erb files in the stack directory' do
      file_list = subject.resource_files
      expect(file_list.select { | f| f.fnmatch('*.yml.erb') }).not_to be_empty
      expect(file_list.select { | f| f.fnmatch('*.yml') }).not_to be_empty
    end
  end

  describe '#resources' do
    before do
      allow(session).to receive(:resource) do |data|
        Pharos::Kube::Resource.new(session, data)
      end
    end

    it 'returns a list of resources' do
      expect(subject.load_resources(vars)).to all(be_an_instance_of(Pharos::Kube::Resource))
    end
  end

  describe '#apply' do
    let(:resource1) { double(:resource1, metadata: OpenStruct.new) }
    let(:resources) { [resource1] }
    let(:random_checksum) { '42' }

    before do
      allow(subject).to receive(:load_resources).with(vars).and_return(resources)
      allow(subject).to receive(:random_checksum).and_return(random_checksum)
    end

    it 'applies all resources' do
      expect(resource1).to receive(:apply) do
        expect(resource1.metadata.labels['pharos.kontena.io/stack']).to eq 'ingress-nginx'
        expect(resource1.metadata.annotations['pharos.kontena.io/stack-checksum']).to eq random_checksum
      end

      expect(subject).to receive(:prune).with(random_checksum)

      subject.apply(vars)
    end
  end
end
