# frozen_string_literal: true

require 'net/ssh'
require 'net/ssh/proxy/jump'

module Pharos
  module Transport
    def self.for(host, **options)
      if host.local?
        Local.new('localhost', **options)
      else
        opts = {}
        opts[:keys] = [host.ssh_key_path] if host.ssh_key_path
        opts[:send_env] = [] # override default to not send LC_* envs
        opts[:proxy] = Net::SSH::Proxy::Command.new(host.ssh_proxy_command) if host.ssh_proxy_command
        opts[:bastion] = host.bastion if host.bastion
        SSH.new(host.address, user: host.user, **opts.merge(options))
      end
    end
  end
end
