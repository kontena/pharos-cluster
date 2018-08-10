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

    context "when not yet installed" do
      let(:resource) {
        K8s::Resource.new(
          apiVersion: 'v1',
          kind: 'ConfigMap',
          metadata: {
            namespace: 'default',
            name: 'test',
            labels: {
              'pharos.kontena.io/stack': 'test',
            },
            annotations: {
              'pharos.kontena.io/stack-checksum': subject.checksum,
            }
          },
          data: {
            'foo' => 'bar',
          }
        )
      }

      before do
        allow(client).to receive(:get_resources).and_return([nil])
        allow(client).to receive(:list_resources).with(labelSelector: { 'pharos.kontena.io/stack' => 'test' }).and_return([resource])
      end

      it "creates the resource with the correct label" do
        expect(client).to receive(:create_resource).with(resource).and_return(resource)

        subject.apply(client)
      end
    end
  end
end
