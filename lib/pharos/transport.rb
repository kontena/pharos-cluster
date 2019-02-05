# frozen_string_literal: true

module Pharos
  module Transport
    def self.for(host, **options)
      if host.local?
        Local.new(host, **options)
      else
        opts = {}
        opts[:keys] = [ssh_key_path] if host.ssh_key_path
        opts[:send_env] = [] # override default to not send LC_* envs
        opts[:proxy] = Net::SSH::Proxy::Command.new(host.ssh_proxy_command) if host.ssh_proxy_command
        opts[:bastion] = host.bastion if host.bastion
        SSH.new(address, user: user, **opts.merge(options)).tap(&:connect)
      end
    end
  end
end
