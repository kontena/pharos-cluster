# frozen_string_literal: true

module Pharos
  class InitCommand < Pharos::Command
    using Pharos::CoreExt::DeepTransformKeys

    banner 'Create a Pharos cluster configuration'

    option %w(-c --config), 'FILE', 'output filename', default: 'cluster.yml', attribute_name: :config_file
    option '--defaults', :flag, 'include all configuration default values'

    option %w(-m --master), 'HOST', 'master host [user@]address[:port] (can be given multiple times)' do |master|
      @hosts ||= []
      @hosts << parse_host(master).merge(role: 'master')
    end

    option %w(-w --worker), 'HOST', 'worker host [user@]address[:port] (can be given multiple times)' do |worker|
      @hosts ||= []
      @hosts << parse_host(worker).merge(role: 'worker')
    end

    option %w(-b --bastion), 'HOST', 'bastion (ssh proxy) host [user@]address[:port]' do |bastion|
      parse_host(bastion)
    end

    option %w(-n --name), 'NAME', 'cluster name'

    option %w(-e --env), 'KEY=VALUE', 'host environment variables (can be given multiple times)', multivalued: true do |kv_pair|
      Hash[*kv_pair.split('=', 2)]
    end

    option %w(-i --ssh-key-path), 'PATH', 'ssh key path'

    def parse_host(host_str)
      user = host_str[/(.+?)@/, 1]
      address = host_str[/(?:.+?@)?([^:]+)/, 1]
      ssh_port = host_str[/:(\d+)/, 1]&.to_i
      { address: address, user: user, ssh_port: ssh_port }
    end

    PRESET_CFG = <<~CONFIG_TPL
      # For full configuration reference, see https://pharos.sh/docs/configuration/
      ---
      name: <%= name  %>

      host_defaults: &host_defaults
        user: <%= host_defaults[:user] %>
        <%- if host_defaults[:ssh_key_path] -%>
        ssh_key_path: <%= host_defaults[:ssh_key_path] %>
        <%- else -%>
        # ssh_key_path: ~/.ssh/id_rsa
        <%- end -%>
        ssh_port: 22
        <%- if host_defaults[:environment] -%>
        environment:
          <%- host_defaults[:environment].each do |key, value| -%>
          <%= key %>: <%= value.inspect %>
          <%- end -%>
        <%- else -%>
        # environment:
        #   HTTP_PROXY: 192.168.0.1
        <%- end -%>
        <%- if host_defaults[:bastion] -%>
        bastion:
          address: <%= host_defaults[:bastion][:address] %>
          <%- if host_defaults[:bastion][:user] -%>
          user: <%= host_defaults[:bastion][:user] %>
          <%- end -%>
          <%- if host_defaults[:bastion][:ssh_port] -%>
          ssh_port: <%= host_defaults[:bastion][:ssh_port] %>
          <%- end -%>
          <%- if host_defaults[:ssh_key_path] -%>
          ssh_key_path: <%= host_defaults[:ssh_key_path] %>
          <%- else -%>
          # ssh_key_path: ~/.ssh/id_rsa
          <%- end -%>
        <%- else -%>
        # bastion:
        #   address: 192.168.0.1
        #   user: bastion
        #   ssh_key_path: ~/.ssh/id_rsa
        <%- end -%>

      hosts:
        <%- hosts.each do |host| -%>
        - <<: *host_defaults
          address: <%= host[:address] %>
          <%- if host[:user] != host_defaults[:user] -%>
          user: <%= host[:user] %>
          <%- end -%>
          <%- if host[:private_address] -%>
          private_address: <%= host[:private_address] %>
          <%- else -%>
          # private_address: 10.0.0.1
          <%- end -%>
          <%- if host[:ssh_port] != host_defaults[:ssh_port] -%>
          ssh_port: <%= host[:ssh_port] %>
          <%- end -%>
          role: <%= host[:role] %>
        <%- end -%>

      network:
        provider: weave

      addons:
        ingress-nginx:
          enabled: true
    CONFIG_TPL

    def default_name
      Pharos::Phases::ConfigureClusterName.new('').random_name
    end

    def host_defaults
      {}.tap do |defaults|
        defaults[:bastion] = bastion if bastion
        defaults[:user] = hosts.find { |h| h[:user] }&.fetch(:user) || ENV['USER'] || 'username'
        defaults[:environment] = env_list.inject(:merge) unless env_list.empty?
        defaults[:ssh_key_path] = ssh_key_path if ssh_key_path
      end
    end

    def hosts
      @hosts ||= [
        # dummy example hosts
        { address: '10.0.0.1', private_address: '172.16.0.1', role: 'master', ssh_key_path: '~/.ssh/id_rsa' },
        { address: '10.0.0.2', private_address: '172.16.0.2', role: 'worker', ssh_key_path: '~/.ssh/id_rsa' }
      ]
    end

    def config_content
      require 'pharos/phases/configure_cluster_name'

      if defaults?
        hosts.each { |h| h.replace(host_defaults.merge(h)) }
        {
          name: name,
          hosts: hosts.map { |h| h.merge(host_defaults) }
        }.merge(Pharos::Config.new.to_h).deep_stringify_keys.to_yaml
      else
        Pharos::YamlFile.new(StringIO.new(PRESET_CFG)).erb_result(
          hosts: hosts,
          host_defaults: host_defaults,
          name: name
        )
      end
    end

    def execute
      signal_error "configuration file #{config_file} already exists" if File.exist?(config_file)
      File.write(config_file, config_content)
    end
  end
end
