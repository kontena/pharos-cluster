describe Kupo::ConfigSchema do

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
  end
end