describe Pharos::CoreExt::DeepKeys do
  using Pharos::CoreExt::DeepKeys

  subject do
    {
      level_a1: {
        level_a2: [
          { level_a2_1: 'hello' },
          { level_a2_2: { level_a2_2_1: 'hello again' } }
        ]
      },
      'level_b1' => { 'level_b2' => { 'level_b3' => 'gutentag' } }
    }
  end

  context '#deep_keys' do
    it 'returns a list of flattened keys' do
      expect(subject.deep_keys).to eq [
        'level_a1.level_a2.0.level_a2_1',
        'level_a1.level_a2.1.level_a2_2.level_a2_2_1',
        'level_b1.level_b2.level_b3'
      ]
    end
  end

  context '#deep_get' do
    it 'can dig the value of a nested key from hash using a dot separated string key' do
      expect(subject.deep_get('level_a1.level_a2.0.level_a2_1')).to eq 'hello'
      expect(subject.deep_get('level_a1.level_a2.1.level_a2_2.level_a2_2_1')).to eq 'hello again'
      expect(subject.deep_get('level_b1.level_b2.level_b3')).to eq 'gutentag'
    end
  end
end
