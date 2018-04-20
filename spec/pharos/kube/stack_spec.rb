describe Pharos::Kube::Stack do
  let(:session) { instance_double(Pharos::Kube::Session) }
  subject { described_class.new(session, 'ingress-nginx') }

  let(:vars) { { default_backend: double(image: 'foo'), configmap: {}, node_selector: {}, arch: double(name: 'foo'), version: '1', image: 'foo'} }

  describe '#resource_files' do
    it 'returns a list of .yml and .yml.erb files in the stack directory' do
      file_list = subject.resource_files
      expect(file_list.select { | f| f.fnmatch('*.yml.erb') }).not_to be_empty
      expect(file_list.select { | f| f.fnmatch('*.yml') }).not_to be_empty
    end
  end

  describe '#load_resources' do
    let(:client) { instance_double(Pharos::Kube::Client) }

    before do
      allow(session).to receive(:resource) do |data|
        Pharos::Kube::Resource.new(session, data)
      end

      allow(session).to receive(:client).and_return(client)
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

  describe '#prune' do
    let(:api_groups) { [
      double(preferredVersion: double(groupVersion: 'test/v1'))
    ] }
    let(:api_client) { instance_double(Pharos::Kube::Client) }
    let(:api_entities) { {
      'Test' => double(resource_name: 'test')
    } }
    let(:resource1) { double(:resource1, metadata: OpenStruct.new(annotations: { 'pharos.kontena.io/stack-checksum' => '41' })) }
    let(:resource2) { double(:resource1, metadata: OpenStruct.new(annotations: { 'pharos.kontena.io/stack-checksum' => '42' })) }
    let(:api_resources) { [resource1, resource2] }

    before do
      allow(session).to receive(:api_groups).and_return(api_groups)
      allow(session).to receive(:client).with('test/v1').and_return(api_client)
      allow(api_client).to receive(:entities).and_return(api_entities)
      allow(api_client).to receive(:get_entities).with('Test', 'test', label_selector: 'pharos.kontena.io/stack=ingress-nginx').and_return(api_resources)
      allow(session).to receive(:resource) do |resource_double| resource_double end

      api_resources.each do |resource|
        allow(resource).to receive(:apiVersion=)
      end
    end

    it "deletes the resource with the wrong checksum" do
      expect(resource1).to receive(:delete)

      subject.prune('42')
    end

    it "deletes all resources without a checksum" do
      expect(resource1).to receive(:delete)
      expect(resource2).to receive(:delete)

      subject.prune()
    end
  end
end
