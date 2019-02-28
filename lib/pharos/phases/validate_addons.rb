# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateAddons < Pharos::Phase
      title "Validate add-ons"

      def call
        addon_manager.validate
        addon_manager.each do |addon|
          addon.apply_modify_cluster_config
        rescue Pharos::Error => e
          error_msg = "#{addon.name} => " + e.message
          raise Pharos::AddonManager::InvalidConfig, error_msg
        end
      end

      def addon_manager
        @addon_manager ||= Pharos::AddonManager.new(@config, cluster_context)
      end
    end
  end
end
