describe Pharos::Kube::Stack do
  let(:session) { double }
  let(:resource) { double(metadata: OpenStruct.new, apply: true) }
  let(:addon_manager) { instance_double(Pharos::AddonManager) }
  subject { described_class.new(session, 'ingress-nginx', default_backend: double(image: 'foo'), configmap: {}, node_selector: {}, arch: double(name: 'foo'), version: '1', image: 'foo', worker_hosts: 2) }

  describe '#resource_files' do
    it 'returns a list of .yml and .yml.erb files in the stack directory' do
      file_list = subject.resource_files
      expect(file_list.select { | f| f.fnmatch('*.yml.erb') }).not_to be_empty
      expect(file_list.select { | f| f.fnmatch('*.yml') }).not_to be_empty
    end
  end

  describe '#resources' do
    it 'returns a list of resources' do
      expect(session).to receive(:resource).with(an_instance_of(Hash)).at_least(:once).and_return(resource)
      expect(subject.resources.all? { |r| r.respond_to?(:apply) }).to be_truthy
    end
  end

  describe '#apply' do
    let(:session) { double(api_groups: []) }

    before do
      allow(session).to receive(:resource).with(an_instance_of(Hash)).at_least(:once).and_return(resource)
    end

    it 'applies all resources' do
      expect(resource).to receive(:apply)
      subject.apply
    end
  end
end
