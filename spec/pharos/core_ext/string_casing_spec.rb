describe Pharos::CoreExt::StringCasing do
  context 'as a module' do
    subject { "fooBar".extend(described_class) }
    it 'underscores a string' do
      expect(subject.underscore).to eq "foo_bar"
    end
  end

  context 'as a refinement' do
    using Pharos::CoreExt::StringCasing

    describe '#underscore' do
      it 'underscores a string' do
        expect("Foo Barbaz".underscore).to eq "foo_barbaz"
        expect("foo BarBaz".underscore).to eq "foo_bar_baz"
        expect("foo barBaz".underscore).to eq "foo_bar_baz"
        expect("fooBARbaz".underscore).to eq "foo_ba_rbaz"
      end
    end

    describe '#camelcase' do
      it 'camelcases a string' do
        expect("foo Bar baz".camelcase).to eq "FooBarBaz"
        expect("foo barBaz".camelcase).to eq "FooBarBaz"
        expect("fooBARbaz".camelcase).to eq "FooBaRbaz"
      end
    end

    describe '#camelback' do
      it 'camelbacks a string' do
        expect("foo Bar baz".camelback).to eq "fooBarBaz"
        expect("foo barBaz".camelback).to eq "fooBarBaz"
        expect("fooBARbaz".camelback).to eq "fooBaRbaz"
      end
    end

    context 'bang' do
      using Pharos::CoreExt::StringCasing

      describe '#underscore' do
        it 'underscores a string' do
          str = "Foo Barbaz"
          str.underscore!
          expect(str).to eq "foo_barbaz"
        end
      end

      describe '#camelcase' do
        it 'camelcases a string' do
          str = "Foo BarBaz"
          str.camelcase!
          expect(str).to eq "FooBarBaz"
        end
      end

      describe '#camelback' do
        it 'camelbacks a string' do
          str = "Foo BarBaz"
          str.camelback!
          expect(str).to eq "fooBarBaz"
        end
      end
    end

    context 'Symbol' do
      using Pharos::CoreExt::StringCasing

      describe '#underscore' do
        it 'stringifies and underscores a symbol' do
          expect(:fooBar.underscore).to eq "foo_bar"
        end
      end

      describe '#camelcase' do
        it 'stringifies and camelcases a symbol' do
          expect(:foo_bar.camelcase).to eq "FooBar"
        end
      end

      describe '#camelback' do
        it 'stringifies and camelbacks a symbol' do
          expect(:foo_bar.camelback).to eq "fooBar"
        end
      end
    end
  end
end
