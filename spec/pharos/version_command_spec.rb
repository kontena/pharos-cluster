describe Pharos::VersionCommand do
  subject { described_class.new('') }

  it 'outputs version with +oss' do
    expect{subject.run([])}.to output(/Kontena Pharos:\n.+?version (\S+)\+oss/m).to_stdout
  end

  context '--version' do
    it 'outputs version with +oss' do
      expect{subject.run(['--version'])}.to output(/.+?version (\S+)\+oss/).to_stdout
    end
  end
end
