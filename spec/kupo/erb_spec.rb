require 'yaml'

describe Kupo::Erb do
  context 'for a yaml file with .yml extension' do
    subject { described_class.new(fixtures_dir('yaml/no_erb.yml')) }

    it 'returns the plain file content' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' => { 'result' => 'success' }
      )
    end
  end

  context 'for an erb file with .yml extension' do
    subject { described_class.new(fixtures_dir('yaml/with_erb_no_extension.yml')) }

    it 'returns the plain file content' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' =>  { 'result' => '<% failure %>' }
      )
    end
  end

  context 'for an erb file with .erb extension' do
    subject { described_class.new(fixtures_dir('yaml/with_erb.yml.erb')) }

    it 'returns the evaluated content' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' =>  { 'result' => 'success' }
      )
    end

    it 'has the erb whitespace trimming enabled' do
      expect(subject.render).to eq File.read(fixtures_dir('yaml/no_erb.yml'))
    end

    it 'passes variables to the erb template' do
      expect(YAML.load(subject.render('hello' => 'hello', result: 'super success'))).to match hash_including(
        'test' =>  { 'result' => 'super success' }
      )
    end
  end
end
