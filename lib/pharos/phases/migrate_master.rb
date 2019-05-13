# frozen_string_literal: true

module Pharos
  module Phases
    class MigrateMaster < Pharos::Phase
      include Pharos::Phases::Mixins::ClusterVersion

      title "Migrate master"

      def call
        if existing_version < build_version('2.4.0-alpha.0')
          migrate_from_2_3
        else
          logger.info "Nothing to migrate."
        end
      end

      def migrate_from_2_3
        logger.info "Triggering certificate refresh ..."
        cluster_context['recreate-etcd-certs'] = true
      end
    end
  end
end
