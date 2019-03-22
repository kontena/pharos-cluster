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
      apply_phase(Phases::ConnectSSH, config.hosts.reject(&:local?), parallel: true)
      apply_phase(Phases::GatherFacts, config.hosts, parallel: true)
      apply_phase(Phases::ConfigureClient, [config.master_host], parallel: false, optional: true)
      apply_phase(Phases::LoadClusterConfiguration, [config.master_host]) if config.master_host.master_sort_score.zero?
      apply_phase(Phases::ConfigureClusterName, %w(localhost))
    end

    def validate
      apply_phase(Phases::UpgradeCheck, %w(localhost))
      addon_manager.validate
      gather_facts
      apply_phase(Phases::ValidateConfigurationChanges, %w(localhost)) if @context['previous-config']
      apply_phase(Phases::ValidateHost, config.hosts, parallel: true)
      apply_phase(Phases::ValidateVersion, [config.master_host], parallel: false)
    end

    def apply_phases
      master_hosts = config.master_hosts
      master_only = [config.master_host]
      apply_phase(Phases::MigrateMaster, master_hosts, parallel: true)
      apply_phase(Phases::ConfigureHost, config.hosts, parallel: true)
      apply_phase(Phases::ConfigureFirewalld, config.hosts, parallel: true)
      apply_phase(Phases::ConfigureClient, master_only, parallel: false, optional: true)

      unless @config.etcd&.endpoints
        etcd_hosts = config.etcd_hosts
        apply_phase(Phases::ConfigureCfssl, etcd_hosts, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, [etcd_hosts.first], parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, [etcd_hosts.first], parallel: false)
        apply_phase(Phases::ConfigureEtcd, etcd_hosts, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, master_hosts, parallel: false)
      apply_phase(Phases::SetupMaster, master_hosts, parallel: true)
      apply_phase(Phases::UpgradeMaster, master_hosts, parallel: false) # requires optional early ConfigureClient

      apply_phase(Phases::MigrateWorker, config.worker_hosts, parallel: true)
      apply_phase(Phases::ConfigureKubelet, config.hosts, parallel: true)

      apply_phase(Phases::PullMasterImages, master_hosts, parallel: true)
      apply_phase(Phases::ConfigureMaster, master_hosts, parallel: false)
      apply_phase(Phases::ConfigureClient, master_only, parallel: false)
      apply_phase(Phases::ReconfigureKubelet, config.hosts, parallel: true)

      # master is now configured and can be used
      # configure essential services
      apply_phase(Phases::ConfigurePriorityClasses, master_only)
      apply_phase(Phases::ConfigurePSP, master_only)
      apply_phase(Phases::ConfigureDNS, master_only)
      apply_phase(Phases::ConfigureWeave, master_only) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico, master_only) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureCustomNetwork, master_only) if config.network.provider == 'custom'
      apply_phase(Phases::ConfigureKubeletCsrApprover, master_only)
      apply_phase(Phases::ConfigureBootstrap, master_only) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, parallel: true)
      apply_phase(Phases::LabelNode, config.hosts, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe

      # configure services that need workers
      apply_phase(Phases::ConfigureMetrics, master_only)
      apply_phase(Phases::ConfigureTelemetry, master_only)
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
    def apply_phase(phase_class, hosts, **options)
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
      master_host = config.master_host
      apply_phase(Phases::StoreClusterConfiguration, [master_host])
    end

    def disconnect
      config.hosts.map { |host| host.transport.disconnect }
    end
  end
end
