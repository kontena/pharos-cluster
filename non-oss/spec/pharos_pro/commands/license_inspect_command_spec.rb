describe Pharos::LicenseInspectCommand do
  subject { described_class.new('') }
  let(:token_status) { 'valid' }
  let(:token_year) { Time.now.year+1 }
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

  describe '#execute' do
    context 'invalid license key' do
      context 'expired' do
        let(:token_year) { Time.now.year - 1 }

        it 'signals error' do
          expect(subject).to receive(:signal_error).with(/not valid/)
          expect{subject.run([license_key])}.to output(/expired/).to_stdout
        end
      end

      context 'status invalid' do
        let(:token_status) { 'invalid' }

        it 'signals error' do
          expect(subject).to receive(:signal_error).with(/not valid/)
          expect{subject.run([license_key])}.to output(/status is/).to_stdout
        end
      end
    end

    context 'valid license key' do
      it 'signals error' do
        expect(subject).not_to receive(:signal_error)
        expect{subject.run([license_key])}.to output(/name.*Pharos Pro License.*created_at.*status.*valid.*valid_until/m).to_stdout
      end
    end
  end
end

