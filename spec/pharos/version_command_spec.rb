describe Pharos::VersionCommand, if: Pharos.oss? do
  subject { described_class.new('') }

  it 'outputs version' do
    expect{subject.run([])}.to output(/Kontena Pharos:\n.+?version (\S+)/m).to_stdout
  end

  context '--version' do
    it 'outputs version' do
      expect{subject.run(['--version'])}.to output(/.+?version (\S+)/).to_stdout
    end
  end
end
