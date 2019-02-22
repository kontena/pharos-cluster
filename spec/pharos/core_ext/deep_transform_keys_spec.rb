describe Pharos::CoreExt::DeepTransformKeys do
  describe '#deep_transform_keys' do
    context 'as a module' do
      subject { { foo: { bar: [ { baz: 1 } ] } } }
      it 'deep transforms keys' do
        subject.extend(described_class)
        expect(subject.deep_transform_keys(&:to_s)).to eq(
          { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } }
        )
      end
    end

    context 'as a refinement' do
      using Pharos::CoreExt::DeepTransformKeys
      subject { { foo: { bar: [ { baz: 1 } ] } } }

      it 'deep transforms keys' do
        expect(subject.deep_transform_keys(&:to_s)).to eq(
          { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } }
        )
      end

      it 'includes the string casing refinement' do
        expect(subject.deep_transform_keys(&:camelcase)).to eq(
          { 'Foo' => { 'Bar' => [ { 'Baz' => 1 } ] } }
        )
      end
    end
  end

  describe '#deep_stringify_keys' do
    context 'as a module' do
      subject { { foo: { bar: [ { baz: 1 } ] } } }
      it 'deep stringifies keys' do
        subject.extend(described_class)
        expect(subject.deep_stringify_keys).to eq(
          { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } }
        )
      end
    end

    context 'as a refinement' do
      using Pharos::CoreExt::DeepTransformKeys
      subject { { foo: { bar: [ { baz: 1 } ] } } }

      it 'deep stringifies keys' do
        expect(subject.deep_stringify_keys).to eq(
          { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } }
        )
      end
    end
  end

  describe '#deep_symbolize_keys' do
    context 'as a module' do
      subject { { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } } }
      it 'deep symbolizes keys' do
        subject.extend(described_class)
        expect(subject.deep_symbolize_keys).to eq(
          { foo: { bar: [ { baz: 1 } ] } }
        )
      end
    end

    context 'as a refinement' do
      using Pharos::CoreExt::DeepTransformKeys
      subject { { 'foo' => { 'bar' => [ { 'baz' => 1 } ] } } }

      it 'deep symbolizes keys' do
        expect(subject.deep_symbolize_keys).to eq(
          { foo: { bar: [ { baz: 1 } ] } }
        )
      end
    end
  end
end
