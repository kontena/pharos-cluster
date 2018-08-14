# frozen_string_literal: true

require 'pharos/ssh/client'
require 'pharos/yaml_file'
require 'pharos/terraform/json_parser'
require 'pharos/kube/config'

module Pharos
  class KubeconfigCommand < Pharos::Command
    option ['-c', '--config'], 'PATH', 'Path to config file (default: cluster.yml)', attribute_name: :config_yaml

    option '--tf-json', 'PATH', 'Path to terraform output json' do |config_path|
      begin
        File.realpath(config_path)
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist: %<path>s' % { path: config_path }
      end
    end

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

    # @return [Pharos::YamlFile]
    def cluster_config
      if config_yaml
        begin
          Pharos::YamlFile.new(File.realpath(config_yaml))
        rescue Errno::ENOENT
          signal_usage_error 'File does not exist: %<path>s' % { path: config_yaml }
        end
      else
        cluster_config = Dir.glob('cluster.{yml,yml.erb}').first
        signal_usage_error 'File does not exist: cluster.yml' if cluster_config.nil?
        Pharos::YamlFile.new(cluster_config)
      end
    end

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
      return @master_host if @master_host
      config_hash = cluster_config.load(ENV.to_h)
      load_terraform(tf_json, config_hash) if tf_json
      config = Pharos::Config.load(config_hash)
      signal_usage_error 'No master hosts defined' if config.master_hosts.empty?
      @master_host = config.master_host
    end

    # @param file [String]
    # @param config [Hash]
    # @return [Hash]
    def load_terraform(file, config)
      tf_parser = Pharos::Terraform::JsonParser.new(File.read(file))
      config['hosts'] ||= []
      config['api'] ||= {}
      config['hosts'] += tf_parser.hosts
      config['api'].merge!(tf_parser.api) if tf_parser.api
      config
    end
  end
end
