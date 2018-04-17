require 'pharos/phases/migrate_worker'

describe Pharos::Phases::MigrateWorker do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, ssh: ssh) }

  describe '#migrate_0_5_to_0_6?' do
    it 'returns false if kubelet.conf does not exist' do
      file = double(:file, exist?: false)
      allow(ssh).to receive(:file).and_return(file)
      expect(subject.migrate_0_5_to_0_6?).to be_falsey
    end

    it 'returns false if kubelet.conf contains right address' do
      file = double(:file, exist?: true, read: 'server: https://localhost:6443/')
      allow(ssh).to receive(:file).and_return(file)
      expect(subject.migrate_0_5_to_0_6?).to be_falsey
    end

    it 'returns true if kubelet.conf contains wrong address' do
      file = double(:file, exist?: true, read: 'server: https://10.10.10.10:6443/')
      allow(ssh).to receive(:file).and_return(file)
      expect(subject.migrate_0_5_to_0_6?).to be_truthy
    end
  end
end