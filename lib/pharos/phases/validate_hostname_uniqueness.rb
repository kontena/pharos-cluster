# frozen_string_literal: true

module Pharos
  module Phases
    class ValidateHostnameUniqueness < Pharos::Phase
      title "Validate host names are unique"

      def call
        dupes = duplicated_hostnames
        return true if dupes.empty?
        raise Pharos::InvalidHostError, "Non-unique hostname#{'s' if dupes.size > 1} #{dupes.join(', ')} found in cluster"
      end

      private

      def duplicated_hostnames
        hostnames = @config.hosts.map(&:hostname)
        hostnames.select { |h| hostnames.count(h) > 1 }.uniq
      end
    end
  end
end
