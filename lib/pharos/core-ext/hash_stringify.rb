# frozen_string_literal: true

module Pharos
  module CoreExt
    module HashStringify
      def stringify_keys
        JSON.parse(JSON.dump(self))
      end
    end
  end
end

Hash.include Pharos::CoreExt::HashStringify
