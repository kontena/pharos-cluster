# frozen_string_literal: true

require_relative 'coreos'

module Pharos
  module Host
    class Flatcar < CoreOS
      register_config 'flatcar', 'stable'
    end
  end
end
