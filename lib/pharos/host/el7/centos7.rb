# frozen_string_literal: true

require_relative 'el7'

module Pharos
  module Host
    class Centos7 < El7
      register_config 'centos', '7'
    end
  end
end
