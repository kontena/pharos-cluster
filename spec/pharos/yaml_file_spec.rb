require 'yaml'

describe Pharos::YamlFile do
  context 'for a yaml file with .yml extension' do
    subject { described_class.new(fixtures_path('yaml/erb/no_erb.yml')) }

    it 'returns the plain yaml content' do
      expect(subject.load).to match hash_including(
        'test' => { 'result' => 'success' }
      )
    end
  end

  context 'for an erb file with .yml extension' do
    subject { described_class.new(fixtures_path('yaml/erb/with_erb_no_extension.yml')) }

    it 'returns the plain yaml content' do
      expect(subject.load).to match hash_including(
        'test' =>  { 'result' => '<% failure %>' }
      )
    end
  end

  context 'for an erb file with .erb extension' do
    subject { described_class.new(fixtures_path('yaml/erb/with_erb.yml.erb')) }

    it 'returns the evaluated yaml content' do
      expect(subject.load(result: nil)).to match hash_including(
        'test' =>  { 'result' => 'success' }
      )
    end

    it 'has the erb whitespace trimming enabled' do
      expect(subject.erb_result(result: nil)).to eq File.read(fixtures_path('yaml/erb/no_erb.yml'))
    end

    it 'passes variables to the erb template' do
      expect(subject.load('hello' => 'hello', result: 'super success')).to match hash_including(
        'test' =>  { 'result' => 'super success' }
      )
    end
  end

  context 'with file-alike input' do
    let(:file) { File.open(fixtures_path('yaml/erb/with_erb.yml.erb')) }
    subject { described_class.new(file) }

    it 'reads the file' do
      expect(file).to receive(:read).and_call_original
      expect(file).to receive(:path).and_call_original
      subject.load(result: 'success')
      expect(subject.filename).to eq fixtures_path('yaml/erb/with_erb.yml.erb')
    end
  end
end
