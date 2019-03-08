# frozen_string_literal: true

module Pharos
  class LicenseInspectCommand < Pharos::Command
    options :load_config, :tf_json

    banner "Display information about the installed license on a Pharos Cluster or a license subscription token"

    option '--subscription-token', '[TOKEN]', 'pharos license subscription token'
    option '--cluster-id', '[ID]', 'pharos cluster id'

    def prepare_config
      return if @prepared_config

      load_config(master_only: true)
      cluster_manager('no-generate-name' => true)
      @prepared_config = true
    end

    def default_subscription_token
      prepare_config
      encoded_jwt = license_secret.data['license.jwt']
      return nil unless encoded_jwt

      Base64.decode64(encoded_jwt)
    end

    def default_cluster_id
      prepare_config
      cluster_context['cluster-id'] || signal_error('Failed to get cluster id')
    end

    def execute
      puts [license_type, owner, valid_until, contact_note].compact

      exit 1 unless valid?
    end

    def license_secret
      kube_client.api('v1').resource('secrets', namespace: 'kube-system').get('pharos-license')
    end

    def license_key
      @license_key ||= Pharos::LicenseKey.new(subscription_token, cluster_id: cluster_id)
    rescue StandardError
      nil
    end

    def cluster_created_at
      Time.parse(cluster_context['cluster-created-at'])
    end

    def evaluation_since
      return Time.now.utc unless cluster_manager.context['cluster-created-at']

      Time.parse(cluster_manager.context['cluster-created-at'])
    end

    def evaluation_valid_until
      @evaluation_valid_until ||= evaluation_since + (30 * 86_400)
    end

    def evaluation_days_remaining
      @evaluation_days_remaining ||= (evaluation_valid_until.to_date - Time.now.utc.to_date).to_i
    end

    def evaluation_data
      return unless license_key.nil?

      { days: evaluation_days_remaining, valid_until: evaluation_valid_until }
    end

    def valid_until_data
      return evaluation_data if license_key.nil?

      {
        days: license_key.days_remaining,
        valid_until: license_key.valid_until.strftime('%B %-d, %Y')
      }
    end

    def valid_until
      if license_key && license_key.days_remaining == Float::INFINITY
        return license_key.status == "valid" ? "Valid forever" : "Manually expired"
      end

      data = valid_until_data

      if valid_until_data[:days].negative?
        "Expired at %<valid_until>s (%<days>s days ago)" % data
      else
        "Valid until %<valid_until>s (%<days>s days remaining)" % data
      end
    end

    def license_type
      return "Kontena Pharos PRO Evaluation License" if license_key.nil?

      "%<name>s for up to %<max_nodes>d nodes" % { name: license_key.data['name'], max_nodes: license_key.data['max_nodes'] }
    end

    def owner
      return if license_key.nil?

      "Licensed to #{license_key.owner}"
    end

    def contact_note
      return if license_key

      "Please contact sales@kontena.io to extend your evaluation"
    end

    def valid?
      license_key&.valid? || evaluation_days_remaining.positive?
    end
  end
end
