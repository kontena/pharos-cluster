require 'pharos/phases/migrate_master'

describe Pharos::Phases::MigrateMaster do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, ssh: ssh) }

  describe '#migrate_0_5_to_0_6?' do
    it 'returns false if etcd.yaml does not exist' do
      file = double(:file, exist?: false)
      allow(ssh).to receive(:file).and_return(file)
      expect(subject.migrate_0_5_to_0_6?).to be_falsey
    end
    it 'returns true if etcd.yaml exists' do
      file = double(:file, exist?: true)
      allow(ssh).to receive(:file).and_return(file)
      expect(subject.migrate_0_5_to_0_6?).to be_truthy
    end
  end
end