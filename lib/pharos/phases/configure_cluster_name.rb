# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureClusterName < Pharos::Phase
      using Pharos::CoreExt::Colorize

      title "Configure cluster name"

      ADJECTIVES = %w(
        autumn hidden bitter misty silent empty dry dark
        summer icy delicate quiet white cool spring winter
        patient twilight dawn crimson wispy weathered blue
        billowing broken cold damp falling frosty green
        long late bold little morning muddy
        red rough still small sparkling shy
        wandering withered wild black young holy solitary
        fragrant aged snowy proud floral restless
        polished purple lively nameless
      ).freeze

      NOUNS = %w(
        waterfall river breeze moon rain wind sea morning
        snow lake sunset pine shadow leaf dawn glitter
        forest hill cloud meadow sun glade bird brook
        butterfly bush dew dust field fire flower firefly
        feather grass haze mountain night pond darkness
        snowflake silence sound sky shape surf thunder
        violet water wildflower wave water resonance sun
        wood dream cherry tree fog frost voice paper
        frog smoke star
      ).freeze

      def call
        use_existing_name || use_config_name || generate_new_name
      end

      def use_existing_name
        existing_name = config_map&.dig('data', 'pharos-cluster-name')
        return false unless existing_name

        logger.info "Cluster name is #{existing_name.magenta}"
        if @config.name && @config.name != existing_name
          raise Pharos::Error, "Cluster name mismatch, cluster: #{existing_name} configuration: #{@config.name}"
        elsif !@config.name
          @config.set(:name, existing_name)
        end

        true
      end

      def use_config_name
        if @config.name
          logger.info "Using cluster name #{@config.name.magenta} from configuration"
        end
      end

      # @return [K8s::Resource, nil]
      def config_map
        cluster_context['previous-config-map']
      end

      def generate_new_name
        return if @config.name

        new_name = "#{ADJECTIVES.sample}-#{NOUNS.sample}-#{"%04d" % rand(9999)}"
        @config.set(:name, new_name)
        logger.info "Using generated random name #{new_name.magenta} as cluster name"
      end
    end
  end
end
