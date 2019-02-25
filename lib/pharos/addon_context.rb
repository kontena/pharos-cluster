# frozen_string_literal: true

module Pharos
  class AddonContext
    using Pharos::CoreExt::StringCasing
    using Pharos::CoreExt::DeepTransformKeys
    using Pharos::CoreExt::Colorize

    def get_binding
      binding
    end
  end
end
