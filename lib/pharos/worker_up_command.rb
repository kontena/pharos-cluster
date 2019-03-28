# frozen_string_literal: true

module Pharos
  class WorkerUpCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    banner <<~BANNER
      Initialize a local or remote host as a Pharos cluster worker.

      #{'Note:'.yellow}
        - Firewalld will not be configured
        - Use #{'pharos exec -r master -f sudo kubeadm token create --print-join-command'.cyan}
          to generate a value for the --join-command option
    BANNER

    options :yes?

    parameter '[ADDRESS]', 'host address', default: "localhost" do |address|
      user, host = address.split('@', 2)
      if host.nil?
        user
      else
        @user = user
        host
      end
    end

    option %w(--ssh-key-path -i), '[PATH]', 'ssh key path'
    option %w(--ssh-port -p), '[PORT]', 'ssh port', default: 22
    option %w(--user -l), '[USER]', 'ssh login username' do |user|
      @user = user
    end

    option '--insecure-registry', '[REGISTRY]', 'insecure registry (can be used multipled times)', multivalued: true
    option '--container-runtime', '[CONTAINER_RUNTIME]', 'container runtime', default: 'cri-o'
    option '--image-repository', '[IMAGE_REPOSITORY]', 'image repository', default: 'registry.pharos.sh/kontenapharos'
    option '--label', '[key=value]', 'node label (can be used multiple times)', multivalued: true do |label|
      signal_usage_error 'invalid --label format' unless label.include?('=')

      label
    end

    option %w(-e --environment-variable), 'KEY=VALUE', 'environment variable key=value (can be given multiple times)' do |kv_pair|
      @env ||= {}
      @env.merge!(Hash[*kv_pair.split('=', 2)])
    end

    option '--control-plane-proxy', :flag, 'enable proxy for control plane'

    option '--join-command', 'CMD', 'cluster join command (see note)', required: true do |join_command|
      signal_usage_error 'invalid --join-command' unless join_command.match?(/kubeadm join.*--token \S+/)

      join_command
    end

    option %w(-m --master-ip), 'ADDRESS', 'master peer address', required: true

    def default_user
      @user
    end

    def host_options
      {}.tap do |options|
        options[:address] = address
        options[:ssh_key_path] = ssh_key_path if ssh_key_path
        options[:ssh_port] = ssh_port
        options[:user] = user if user
        options[:role] = 'worker'
        options[:container_runtime] = container_runtime
        options[:labels] = label_list.map { |l| l.split('=') }.to_h
        options[:environment] = @env if @env
      end
    end

    def host
      @host ||= Pharos::Configuration::Host.new(host_options)
    end

    def master_host
      @master_host ||= Pharos::Configuration::Host.new(address: master_ip)
    end

    def config
      @config ||= Pharos::Config.new(
        hosts: [host, master_host],
        container_runtime: Pharos::Configuration::ContainerRuntime.new(insecure_registries: insecure_registry_list),
        image_repository: image_repository,
        network: Pharos::Configuration::Network.new,
        control_plane: Pharos::Configuration::ControlPlane.new(use_proxy: control_plane_proxy?)
      )
    end

    def cluster_manager
      @cluster_manager ||= ClusterManager.new(config).tap do |manager|
        puts "==> Sharpening tools ...".green
        manager.context['join-command'] = join_command
        manager.load
      end
    end

    def gather_facts
      cluster_manager.apply_phase(Phases::ConnectSSH, config.worker_hosts.reject(&:local?))
      cluster_manager.apply_phase(Phases::GatherFacts, config.worker_hosts)
      cluster_manager.apply_phase(Phases::ValidateHost, config.worker_hosts)
    end

    def label_node
      host.labels.each do |key, value|
        host.transport.exec!("sudo kubectl --kubeconfig=/etc/kubernetes/kubelet.conf label nodes --overwrite=true #{host.hostname} #{"#{key}=#{value}".inspect}")
      end
    end

    def apply_phases
      cluster_manager.apply_phase(Phases::ConfigureHost, config.worker_hosts)
      cluster_manager.apply_phase(Phases::MigrateWorker, config.worker_hosts)
      cluster_manager.apply_phase(Phases::ConfigureKubelet, config.worker_hosts)
      cluster_manager.apply_phase(Phases::JoinNode, config.worker_hosts)
      label_node
    end

    def disconnect
      cluster_manager.disconnect
    end

    def execute
      start_time = Time.now

      cluster_manager.config.worker_hosts.first.config = config
      ENV.update(@env) if cluster_manager.config.worker_hosts.first.local? && @env

      gather_facts
      apply_phases
      disconnect

      craft_time = Time.now - start_time
      puts "==> Worker has been crafted! (took #{humanize_duration(craft_time.to_i)})".green
    end
  end
end
