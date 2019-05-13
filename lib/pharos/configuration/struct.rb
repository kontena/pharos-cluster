# frozen_string_literal: true

require 'dry-struct'

module Pharos
  module Configuration
    class Struct < Dry::Struct
      transform_types do |type|
        # all attributes are optional and default to nil...
        type.meta(omittable: true)
      end
    end
  end
end
