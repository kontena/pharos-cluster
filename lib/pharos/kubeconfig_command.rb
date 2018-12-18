# frozen_string_literal: true

module Pharos
  class KubeconfigCommand < Pharos::Command
    options :load_config

    option ['-n', '--name'], 'NAME', 'overwrite cluster name', attribute_name: :new_name
    option ['-C', '--context'], 'CONTEXT', 'overwrite context name', attribute_name: :new_context
    option ['-m', '--merge'], '[FILE]', 'merge with existing configuration file', multivalued: true

    REMOTE_FILE = "/etc/kubernetes/admin.conf"

    def execute
      Dir.chdir(config_yaml.dirname) do
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
    end

    private

    def config_file_content
      file = ssh.file(REMOTE_FILE)
      signal_usage_error "Remote file #{REMOTE_FILE} not found" unless file.exist?
      file.read
    end

    def ssh
      @ssh ||= master_host.ssh
    end

    # @return [Pharos::Config]
    def master_host
      @master_host ||= load_config.master_host
    end
  end
end
