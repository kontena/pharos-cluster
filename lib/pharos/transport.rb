# frozen_string_literal: true

module Pharos
  module Transport
    def self.for(host)
      if host.local?
        Local.new('localhost')
      elsif host.bastion
        host.bastion.host.gateway.ssh(host)
      else
        SSH.new(host)
      end
    end
  end
end
