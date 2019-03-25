# frozen_string_literal: true

module Pharos
  module Phases
    module Mixins
      module ClusterVersion
        # @return [Gem::Version]
        def existing_version
          if cluster_version = cluster_context.existing_pharos_version
            build_version(cluster_version)
          else
            build_version('0.0.1')
          end
        end

        # @return [Gem::Version]
        def pharos_version
          @pharos_version ||= build_version(Pharos::VERSION)
        end

        # @param version [String]
        # @return [Gem::Version]
        def build_version(version)
          Gem::Version.new(version.gsub(/\+.*/, ''))
        end
      end
    end
  end
end
