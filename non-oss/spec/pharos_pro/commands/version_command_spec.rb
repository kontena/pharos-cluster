describe Pharos::VersionCommand do
  subject { described_class.new('') }

  it 'outputs version without +oss' do
    expect{subject.run([])}.to output(/Kontena Pharos:\n.+?version \d+\.\d+\.\d+(?:\-[\+]+)?\n/m).to_stdout
  end

  context '--version' do
    it 'outputs version with +oss' do
      expect{subject.run(['--version'])}.to output(/.+?version \d+\.\d+\.\d+(?:\-[\+]+)?\n/).to_stdout
    end
  end
end

