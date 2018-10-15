# frozen_string_literal: true

module Pharos
  module Addons
    class Kured < Pharos::Addon
      addon_name 'kured'
      version 'master-b27aaa1'
      license 'Apache License 2.0'

      install {
        logger.warn { '~~~> kured is deprecated!' }
        logger.warn { '~~~> see https://www.pharos.sh/docs/addons/kured.html' }
        apply_resources
      }
    end
  end
end
