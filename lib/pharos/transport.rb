# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/proxy/jump'

module Pharos
  module Transport
    def self.for(host)
      if host.local?
        Local.new('localhost')
      else
        SSH.new(host)
      end
    end
  end
end
