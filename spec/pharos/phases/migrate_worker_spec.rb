require 'pharos/phases/migrate_worker'

describe Pharos::Phases::MigrateWorker do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::Transport::SSH) }
  subject { described_class.new(host) }

  before do
    allow(host).to receive(:transport).and_return(ssh)
  end
end
