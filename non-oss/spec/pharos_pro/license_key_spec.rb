describe Pharos::LicenseKey do
  let(:token_status) { 'valid' }
  let(:token_year) { Time.now.year+1 }
  let(:cluster_id) { 'test' }
  let(:token_data) do
    {
      "data"=> {
        "name" => "Pharos Pro License",
        "cluster_id" => "test",
        "key" => nil,
        "created_at" => "2019-02-12 12:52:38 UTC",
        "status" => token_status,
        "valid_until" => "#{token_year}-01-30",
        "owner" => "test"
      },
      "exp" => 1580428799
    }
  end

  let(:license_key) do
    [
      Base64.encode64('{"alg":"RS256"}'),
      Base64.encode64(JSON.dump(token_data)),
      'fake signature'
    ].join('.')
  end

  subject { described_class.new(license_key, cluster_id: cluster_id) }

  describe '#valid?' do
    context 'with invalid license key' do
      context 'when license has expired' do
        let(:token_year) { Time.now.year - 1 }

        it 'is falsey' do
          expect(subject.valid?).to be_falsey
          expect(subject.errors).to match array_including(/expired/)
        end
      end

      context 'when status is invalid' do
        let(:token_status) { 'invalid' }

        it 'is falsey' do
          expect(subject.valid?).to be_falsey
          expect(subject.errors).to match array_including(/status/)
        end
      end

      context 'when cluster id is wrong' do
        let(:cluster_id) { 'foo' }

        it 'valid? is false' do
          expect(subject.valid?).to be_falsey
          expect(subject.errors).to match array_including(/not for this/)
        end
      end
    end

    context 'valid license key' do
      context 'cluster id not given' do
        let(:cluster_id) { nil }

        it 'is truthy' do
          expect(subject.valid?).to be_truthy
        end
      end

      it 'is truthy' do
        expect(subject.valid?).to be_truthy
      end
    end
  end
end
