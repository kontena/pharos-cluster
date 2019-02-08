require 'pharos/phases/migrate_worker'

describe Pharos::Phases::MigrateWorker do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host) }

  before do
    allow(host).to receive(:ssh).and_return(ssh)
  end
end
