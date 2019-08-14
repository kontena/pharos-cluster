require "pharos/phase"

describe Pharos::Phase do
  let(:host) { double(:host) }
  let(:config) { double(:config) }
  let(:cluster_context) { {} }
  let(:subject) { described_class.new(host, config: config, cluster_context: cluster_context) }

  describe '#worker_pool' do
    it 'returns FixedThreadPool' do
      pool = subject.worker_pool('foo', 2)
      expect(pool).to be_instance_of(Concurrent::FixedThreadPool)
    end

    it 'returns the same pool if asked twice' do
      pool1 = subject.worker_pool('foo', 2)
      pool2 = subject.worker_pool('foo', 2)
      expect(pool1).to eq(pool2)
    end

    it 'returns a different pool if asked twice with different name' do
      pool1 = subject.worker_pool('foo', 2)
      pool2 = subject.worker_pool('bar', 2)
      expect(pool1).not_to eq(pool2)
    end
  end

  describe '#throttled_work' do
    it 'runs given block' do
      value = subject.throttled_work('foo', 2) do
        'bar'
      end
      expect(value).to eq('bar')
    end

    it 'raises re-raises exceptions' do
      expect {
        subject.throttled_work('foo', 2) do
          raise 'bar'
        end
      }.to raise_error(StandardError)
    end
  end
end
