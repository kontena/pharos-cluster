require 'yaml'

describe Kupo::Erb do
  context 'for a yaml file with .yml extension' do
    subject { described_class.new(fixtures_dir('yaml/erb/no_erb.yml')) }

    it 'returns the plain file content' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' => { 'result' => 'success' }
      )
    end
  end

  context 'for an erb file with .yml extension' do
    subject { described_class.new(fixtures_dir('yaml/erb/with_erb_no_extension.yml')) }

    it 'returns the plain file content' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' =>  { 'result' => '<% failure %>' }
      )
    end
  end

  context 'for an erb file with .erb extension' do
    subject { described_class.new(fixtures_dir('yaml/erb/with_erb.yml.erb')) }

    it 'returns the evaluated content' do
      expect(YAML.load(subject.render(result: nil))).to match hash_including(
        'test' =>  { 'result' => 'success' }
      )
    end

    it 'has the erb whitespace trimming enabled' do
      expect(subject.render(result: nil)).to eq File.read(fixtures_dir('yaml/erb/no_erb.yml'))
    end

    it 'passes variables to the erb template' do
      expect(YAML.load(subject.render(result: 'super success'))).to match hash_including(
        'test' =>  { 'result' => 'super success' }
      )
    end
  end

  context 'for an erb file with unknown local variable' do
    subject { described_class.new(fixtures_dir('yaml/erb/with_unknown_variable.yml.erb')) }

    it 'raises an error with hint about the filename' do
      expect{subject.render}.to raise_error(Kupo::Erb::Namespace::Error, /unknown local variable.*with_unknown_variable.yml.erb/)
    end
  end

  context 'for an erb file with conditional assignment to a nil local variable' do
    subject { described_class.new(fixtures_dir('yaml/erb/with_unknown_variable_assignment.yml.erb')) }

    it 'raises nothing and renders as expected' do
      expect(YAML.load(subject.render)).to match hash_including(
        'test' => { 'result' => 'success' }
      )
    end
  end

  context 'for an erb file with conditional logic with a nil local variable' do
    subject { described_class.new(fixtures_dir('yaml/erb/with_unknown_variable_conditional.yml.erb')) }

    it 'raises nothing and renders as expected' do
      expect(YAML.load(subject.render(local_var: nil))).to match hash_including(
        'test' => { 'result' => 'itsnil' }
      )
      expect(YAML.load(subject.render(local_var: 'notnil'))).to match hash_including(
        'test' => { 'result' => 'notnil' }
      )
    end
  end
end
