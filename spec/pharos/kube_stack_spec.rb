describe Pharos::Kube::Stack do
  describe "for a trivial test stack" do
    let(:client) { instance_double(K8s::Client) }

    subject do
      described_class.load('test', fixtures_path('stacks/test'))
    end

    it "has the correct name" do
      expect(subject.name).to eq 'test'
    end

    it "has the resource" do
      expect(subject.resources.map{|r| r.to_hash}).to match [
        hash_including(
          metadata: {
            namespace: 'default',
            name: 'test',
          },
        )
      ]
    end

    it "labels resources with the correct label and annotation" do
      expect(described_class::LABEL).to eq 'pharos.kontena.io/stack'

      expect(subject.resources.map{|r| subject.prepare_resource(r).to_hash}).to match [
        hash_including(
          metadata: hash_including(
            namespace: 'default',
            name: 'test',
            labels: { :'pharos.kontena.io/stack' => 'test' },
            annotations: {
              :'pharos.kontena.io/stack-checksum' => anything,
              :'kubectl.kubernetes.io/last-applied-configuration' => JSON.dump(YAML.load(File.read(fixtures_path('stacks/test/test.yml'))))
            },
          ),
        ),
      ]
    end
  end

  context "stack with empty resources" do
    let(:client) { instance_double(K8s::Client) }

    subject do
      described_class.load('test', fixtures_path('stacks/empty'))
    end

    it "ignores empty resources during stack loading" do
      expect(subject.resources.size).to eq(1)
      expect(subject.resources.first.kind).not_to be_nil
      expect(subject.resources.first.apiVersion).not_to be_nil
    end
  end
end
