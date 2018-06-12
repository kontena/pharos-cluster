require 'pharos/phases/migrate_worker'

describe Pharos::Phases::MigrateWorker do
  let(:host) { instance_double(Pharos::Configuration::Host) }
  let(:ssh) { instance_double(Pharos::SSH::Client) }
  subject { described_class.new(host, ssh: ssh) }
end