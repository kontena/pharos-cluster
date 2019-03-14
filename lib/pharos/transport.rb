# frozen_string_literal: true

require 'net/ssh/proxy/gateway'

module Pharos
  module Transport
    def self.gateways
      @gateways ||= {}
    end

    def self.gateway(host)
      gateways[host] ||= Net::SSH::Proxy::Gateway.new(host.address, host.user, SSH.options_for(host))
    end
  end
end
