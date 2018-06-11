# frozen_string_literal: true

require_relative 'el7'

module Pharos
  module Host
    class Rhel7 < El7
      register_config 'rhel', '7.4'
      register_config 'rhel', '7.5'
    end
  end
end
