# frozen_string_literal: true

require 'pharos/up_command'
require 'pharos/ssh/client'
require 'pharos/yaml_file'
require 'pharos/terraform/json_parser'
require 'pharos/kube/config'

module Pharos
  class KubeconfigCommand < UpCommand
    option ['-n', '--name'], 'NAME', 'Overwrite cluster name', attribute_name: :new_name
    option ['-C', '--context'], 'CONTEXT', 'Overwrite context name', attribute_name: :new_context
    option ['-m', '--merge'], '[FILE]', 'Merge with existing configuration file', multivalued: true

    REMOTE_FILE = "/etc/kubernetes/admin.conf"

    def execute
      config = Pharos::Kube::Config.new(config_file_content)
      config.rename_cluster(new_name) if new_name
      config.rename_context(new_context) if new_context
      config.update_server_address(master_host.api_address)
      merge_list.each do |merge|
        merge_config = Pharos::Kube::Config.new(File.read(merge))
        config << merge_config
      end
      puts config
    end

    private

    def config_file_content
      file = ssh.file(REMOTE_FILE)
      signal_usage_error "Remote file #{REMOTE_FILE} not found" unless file.exist?
      file.read
    end

    def ssh
      return @ssh if @ssh
      opts = {}
      opts[:keys] = [master_host.ssh_key_path] if master_host.ssh_key_path
      @ssh = Pharos::SSH::Client.new(master_host.address, master_host.user, opts).tap(&:connect)
    end

    # @return [Pharos::Config]
    def master_host
      @master_host ||= load_config.master_host
    end
  end
end
