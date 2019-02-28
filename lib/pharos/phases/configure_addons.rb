# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureAddons < Pharos::Phase
      using Pharos::CoreExt::Colorize

      title "Configure add-ons"

      def call
        addon_manager.each do |addon|
          logger.info "#{addon.enabled? ? 'Enabling'.green : 'Disabling'.red} addon #{addon.name}".cyan

          addon.apply
          post_install_messages[addon.name] = addon.post_install_message if addon.post_install_message
        end
      end

      def post_install_messages
        cluster_context['post_install_messages']
      end

      def addon_manager
        Pharos::AddonManager.new(@config, cluster_context)
      end
    end
  end
end
