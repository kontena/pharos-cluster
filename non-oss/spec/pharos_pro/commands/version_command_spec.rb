describe Pharos::VersionCommand do
  subject { described_class.new('') }

  it 'outputs pharos version' do
    expect{subject.run([])}.to output(/Kontena Pharos:\n[^\n]+?(\d+\.\d+\.\d+)/).to_stdout
  end

  it 'outputs version without +oss' do
    expect{subject.run([])}.not_to output(/\+oss$/m).to_stdout
  end

  context '--version' do
    it 'outputs version with +oss' do
      expect{subject.run(['--version'])}.not_to output(/\+oss$/m).to_stdout
    end
  end
end

