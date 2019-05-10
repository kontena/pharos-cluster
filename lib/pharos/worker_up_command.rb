# frozen_string_literal: true

module Pharos
  class WorkerUpCommand < Pharos::Command
    using Pharos::CoreExt::Colorize
    using Pharos::CoreExt::DeepTransformKeys

    banner <<~BANNER
      Initialize a local or remote host as a Pharos cluster worker.

      #{'Note:'.yellow}
        - Use #{'pharos exec -r master -f sudo kubeadm token create --print-join-command'.cyan}
          to generate a value for the join-command parameter
    BANNER

    parameter 'JOIN_COMMAND', 'cluster join command (see note)', required: true do |join_command|
      signal_usage_error 'invalid --join-command' unless join_command.match?(/--token \S+/)

      join_command.insert(0, 'kubeadm join ') unless join_command.include?('kubeadm join')
      join_command.delete_prefix('sudo ')
    end

    parameter 'ADDRESS ...', 'master peer address (can be given multiple times)', attribute_name: :master_address_list

    options :yes?

    option %w(-h --host), '[ADDRESS]', 'ssh host address', default: "localhost", attribute_name: :host_address do |address|
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

    option '--insecure-registry', '[REGISTRY]', 'insecure registry (can be given multipled times)', multivalued: true
    option '--image-repository', '[IMAGE_REPOSITORY]', 'image repository', default: 'registry.pharos.sh/kontenapharos'
    option '--cloud-provider', '[NAME]', 'cloud provider'
    option '--container-runtime', '[CONTAINER_RUNTIME]', 'container runtime', default: 'docker'
    option '--label', '[key=value]', 'node label (can be given multiple times)', multivalued: true do |label|
      signal_usage_error 'invalid --label format' unless label.include?('=')

      label
    end

    option %w(-e --env), 'KEY=VALUE', 'environment variable key=value (can be given multiple times)' do |kv_pair|
      @env ||= {}
      @env.merge!(Hash[*kv_pair.split('=', 2)])
    end

    option '--control-plane-proxy', :flag, 'enable proxy for control plane'

    def default_user
      @user
    end

    def host_options
      {}.tap do |options|
        options[:address] = host_address
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

    def master_hosts
      master_address_list.map { |address| Pharos::Configuration::Host.new(address: address, role: 'master') }
    end

    def config
      @config ||= Pharos::Config.new(
        hosts: [host] + master_hosts,
        container_runtime: Pharos::Configuration::ContainerRuntime.new(insecure_registries: insecure_registry_list),
        image_repository: image_repository,
        network: Pharos::Configuration::Network.new,
        control_plane: Pharos::Configuration::ControlPlane.new(use_proxy: control_plane_proxy?),
        cloud: Pharos::Configuration::Cloud.new(provider: cloud_provider)
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

    def apply_phases
      host.configurer.kubelet_args.concat(['--node-labels', host.labels.map { |k, v| [k, v].join('=') }.join(',')])

      cluster_manager.apply_phase(Phases::ConfigureHost, config.worker_hosts)
      cluster_manager.apply_phase(Phases::MigrateWorker, config.worker_hosts)
      cluster_manager.apply_phase(Phases::ConfigureKubelet, config.worker_hosts)
      cluster_manager.apply_phase(Phases::JoinNode, config.worker_hosts)
    end

    def apply_stage2_phases
      cluster_manager.apply_phase(Phases::ReconfigureKubelet, config.worker_hosts)
    end

    def update_masters
      master_nodes = YAML.safe_load(host.transport.exec!('sudo kubectl get nodes --kubeconfig /etc/kubernetes/kubelet.conf -l node-role.kubernetes.io/master -o yaml'))
      new_master_hosts = []
      master_nodes['items']&.each do |master|
        addresses = master.dig('status', 'addresses')
        next unless addresses

        master_address = addresses.find { |m| m['type'] == 'InternalIP' } || addresses.find { |m| m['type'] == 'ExternalIP' }
        new_master_hosts << Pharos::Configuration::Host.new(address: master_address['address'], role: 'master') if master_address
      end
      return false if new_master_hosts.empty? || new_master_hosts.map(&:address) == config.master_hosts.map(&:address)

      config.hosts.delete_if(&:master?)
      config.hosts.concat(new_master_hosts)

      true
    end

    def disconnect
      cluster_manager.disconnect
    end

    def execute
      lexer = Rouge::Lexers::YAML.new
      puts "==> Configuration is generated and shown below:".green
      stripped_config = config.to_h.deep_stringify_keys.slice('hosts', 'cloud', 'control_plane', 'image_repository', 'container_runtime')
      if color?
        puts rouge.format(lexer.lex(YAML.dump(stripped_config).delete_prefix("---\n")))
        puts ""
      else
        puts config.to_yaml.delete_prefix("---\n")
      end

      confirm_yes!('Continue?', default: true)

      start_time = Time.now

      host.config = config
      ENV.update(@env) if config.worker_hosts.first.local? && @env

      gather_facts
      apply_phases
      apply_stage2_phases if update_masters
      disconnect

      craft_time = Time.now - start_time
      puts "==> Worker has been crafted! (took #{humanize_duration(craft_time.to_i)})".green
    end
  end
end
