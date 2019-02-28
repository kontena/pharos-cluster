# frozen_string_literal: true

module Pharos
  class LicenseAssignCommand < Pharos::Command
    options :load_config, :license_key

    parameter "[LICENSE_KEY]", "kontena pharos license key or subscription token"
    option '--description', 'DESCRIPTION', "license description [DEPRECATED]", hidden: true
    option %w(-f --force), :flag, "force assign invalid/expired token"
    option '--token', :flag, "display license subscription token" do
      if jwt_token.valid?
        puts jwt_token.token
        exit
      end

      signal_error "Token invalid: #{jwt_token.errors.join('. ')}"
    end

    def execute
      warn '[DEPRECATED] the --description option is deprecated and will be ignored' if description

      puts decorate_license

      unless jwt_token.valid? || force?
        signal_error "License is not valid"
      end

      Dir.chdir(config_yaml.dirname) do
        master_host.transport.connect
        master_host.transport.exec!("kubectl create secret generic pharos-cluster --namespace=kube-system --from-literal='license.jwt=#{jwt_token.token}' --dry-run -o yaml | kubectl apply -f -")
        logger.info "Added subscription token to pharos cluster secrets"
      end
    end
  end
end
