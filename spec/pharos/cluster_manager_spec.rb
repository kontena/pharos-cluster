describe Pharos::ClusterManager do
  context '#format_hosts' do
    subject { described_class.new('', config_content: '') }
    let(:hosts) do
      [
        '10.2.3.4', '10.2.3.56', '192.168.100.4', '192.168.23.254',
        '172.15.23.51', '83.123.12.2', '100.100.100.100', '32.2.1.2'
      ]
    end

    it 'displays just the count of hosts when there are many' do
      expect(subject.format_hosts(hosts)).to eq "#{hosts.size} hosts"
    end

    it 'displays the full list of nodes when there are just a few' do
      expect(subject.format_hosts(hosts.first(3))).to eq "10.2.3.4, 10.2.3.56, 192.168.100.4"
    end

    it 'displays a grouped list of nodes when the group count is suitable' do
      expect(subject.format_hosts(hosts.first(5))).to eq "10.2.* (2 hosts), 192.168.* (2 hosts), 172.15.23.51"
    end
  end
end
