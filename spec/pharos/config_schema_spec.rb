describe Pharos::ConfigSchema do

  describe '.build' do

    let(:subject) { described_class.build }

    context 'hosts' do
      it 'returns errors if no hosts' do
        result = subject.call({})
        expect(result.success?).to be_falsey
        expect(result.errors[:hosts]).not_to be_empty
      end

      it 'returns error if hosts is empty' do
        result = subject.call({ "hosts" => []})
        expect(result.success?).to be_falsey
        expect(result.errors[:hosts]).not_to be_empty
      end
    end

    context 'addons' do
      it 'accepts empty hash' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {}
        })
        expect(result.success?).to be_truthy
      end

      it 'accepts config withoud addons' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ]
        })
        expect(result.success?).to be_truthy
      end
    end

    context 'etcd' do
      it 'works without etcd' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {}
        })
        expect(result.success?).to be_truthy
      end

      it 'requires endpoints' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "etcd" => {}
        })
        expect(result.success?).to be_falsey
      end

      it 'sets endpoints' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "etcd" => {
            "endpoints" => [
              "https://192.168.1.2"
            ]
          }
        })
        expect(result.success?).to be_truthy
        expect(result.to_h.dig(:etcd, :endpoints, 0)).to eq("https://192.168.1.2")
      end
    end

    context 'cloud' do
      it 'works without cloud' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {}
        })
        expect(result.success?).to be_truthy
      end

      it 'works with cloud provider' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "cloud" => {
            "provider" => "external"
          }
        })
        expect(result.success?).to be_truthy
      end

      it 'works without cloud config' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "cloud" => {
            "provider" => "external"
          }
        })
        expect(result.success?).to be_truthy
      end

      it 'errors without provider' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "cloud" => {}
        })
        expect(result.success?).to be_falsey
      end

      it 'errors with invalid config format' do
        result = subject.call({
          "hosts" => [
            { address: '1.1.1.1', role: 'master' }
          ],
          "addons" => {},
          "cloud" => {
            "provider" => "external",
            "config" => {}
          }
        })
        expect(result.success?).to be_falsey
      end
    end
  end
end