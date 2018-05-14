describe Pharos::Kube::Client do
  describe 'self.from_config' do
    let(:config) { double(
      context: double(
        api_endpoint: 'https://localhost:6443',
        ssl_options: {},
        auth_options: {},
      ),
    ) }

    it 'uses the correct settings for the default API' do
      subject = described_class.from_config(config, 'v1')

      expect(subject.api_endpoint.to_s).to eq 'https://localhost:6443/api'
      expect(subject.instance_variable_get('@api_version')).to eq 'v1'
      expect(subject.instance_variable_get('@api_group')).to eq ''
    end

    it 'uses the correct settings for an extension API' do
      subject = described_class.from_config(config, 'apps/v1')

      expect(subject.api_endpoint.to_s).to eq 'https://localhost:6443/apis/apps'
      expect(subject.instance_variable_get('@api_version')).to eq 'v1'
      expect(subject.instance_variable_get('@api_group')).to eq 'apps/'
    end
  end

end
