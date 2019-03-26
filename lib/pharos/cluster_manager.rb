# frozen_string_literal: true

require 'pathname'

module Pharos
  class ClusterManager
    include Pharos::Logging
    using Pharos::CoreExt::Colorize

    attr_reader :config, :context

    def self.phase_dirs
      @phase_dirs ||= [
        File.join(__dir__, 'phases')
      ]
    end

    def self.addon_dirs
      @addon_dirs ||= [
        File.join(__dir__, '..', '..', 'addons'),
        File.join(Dir.pwd, 'pharos-addons')
      ]
    end

    # @param config [Pharos::Config]
    def initialize(config)
      @config = config
      @context = {
        'post_install_messages' => {}
      }
    end

    # @return [Pharos::AddonManager]
    def phase_manager
      @phase_manager ||= Pharos::PhaseManager.new(
        config: @config,
        cluster_context: @context
      )
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new(@config, @context)
    end

    # load phases/addons
    def load
      Pharos::PhaseManager.load_phases(*self.class.phase_dirs)
      addon_dirs = self.class.addon_dirs + @config.addon_paths.map { |d| File.join(Dir.pwd, d) }

      addon_dirs.keep_if { |dir| File.exist?(dir) }
      addon_dirs = addon_dirs.map { |dir| Pathname.new(dir).realpath.to_s }.uniq

      Pharos::AddonManager.load_addons(*addon_dirs)
      Pharos::Host::Configurer.load_configurers
    end

    def gather_facts
      apply_phase(Phases::ConnectSSH, parallel: true)
      apply_phase(Phases::GatherFacts, parallel: true)
      apply_phase(Phases::ConfigureClient, parallel: false)
      apply_phase(Phases::LoadClusterConfiguration) if config.master_host.master_sort_score.zero?
      apply_phase(Phases::ConfigureClusterName)
    end

    def validate
      apply_phase(Phases::UpgradeCheck)
      addon_manager.validate
      gather_facts
      apply_phase(Phases::ValidateConfigurationChanges) if @context['previous-config']
      apply_phase(Phases::ValidateHost, parallel: true)
      apply_phase(Phases::ValidateVersion, parallel: false)
    end

    def apply_phases
      apply_phase(Phases::MigrateMaster, parallel: true)
      apply_phase(Phases::ConfigureHost, parallel: true)
      apply_phase(Phases::ConfigureFirewalld, parallel: true)
      apply_phase(Phases::ConfigureClient, parallel: false)

      unless @config.etcd&.endpoints
        apply_phase(Phases::ConfigureCfssl, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, parallel: false)
        apply_phase(Phases::ConfigureEtcd, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, parallel: false)
      apply_phase(Phases::SetupMaster, parallel: true)
      apply_phase(Phases::UpgradeMaster, parallel: false)

      apply_phase(Phases::MigrateWorker, parallel: true)
      apply_phase(Phases::ConfigureKubelet, parallel: true)

      apply_phase(Phases::PullMasterImages, parallel: true)
      apply_phase(Phases::ConfigureMaster, parallel: false)
      apply_phase(Phases::ConfigureClient, parallel: false)
      apply_phase(Phases::ReconfigureKubelet, parallel: true)

      # master is now configured and can be used
      # configure essential services
      apply_phase(Phases::ConfigurePriorityClasses)
      apply_phase(Phases::ConfigurePSP)
      apply_phase(Phases::ConfigureCloudProvider)
      apply_phase(Phases::ConfigureDNS)
      apply_phase(Phases::ConfigureWeave) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureCustomNetwork) if config.network.provider == 'custom'
      apply_phase(Phases::ConfigureKubeletCsrApprover)
      apply_phase(Phases::ConfigureBootstrap) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, parallel: true)
      apply_phase(Phases::LabelNode, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe

      # configure services that need workers
      apply_phase(Phases::ConfigureMetrics)
      apply_phase(Phases::ConfigureTelemetry)
    end

    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_reset_hosts(hosts)
      master_hosts = config.master_hosts
      if master_hosts.first.master_sort_score.zero?
        apply_phase(Phases::Drain, hosts, parallel: false)
        apply_phase(Phases::DeleteHost, hosts, parallel: false)
      end
      addon_manager.each do |addon|
        next unless addon.enabled?

        puts "==> Resetting addon #{addon.name}".cyan
        hosts.each do |host|
          addon.apply_reset_host(host)
        end
      end
      apply_phase(Phases::ResetHost, hosts, parallel: true)
    end

    def apply_addons_cluster_config_modifications
      addon_manager.each do |addon|
        addon.apply_modify_cluster_config
      rescue Pharos::Error => e
        error_msg = "#{addon.name} => " + e.message
        raise Pharos::AddonManager::InvalidConfig, error_msg
      end
    end

    # @param phase_class [Pharos::Phase]
    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_phase(phase_class, hosts = nil, **options)
      hosts = phase_class.hosts_for(config) if hosts.nil?
      return if hosts.empty?

      puts "==> #{phase_class.title} @ #{hosts.join(' ')}".cyan

      phase_manager.apply(phase_class, hosts, **options)
    end

    def apply_addons
      addon_manager.each do |addon|
        puts "==> #{addon.enabled? ? 'Enabling' : 'Disabling'} addon #{addon.name}".cyan

        addon.apply
        post_install_messages[addon.name] = addon.post_install_message if addon.post_install_message
      end
    end

    def post_install_messages
      @context['post_install_messages']
    end

    def save_config
      apply_phase(Phases::StoreClusterConfiguration)
    end

    def disconnect
      config.hosts.map { |host| host.transport.disconnect }
    end
  end
end
