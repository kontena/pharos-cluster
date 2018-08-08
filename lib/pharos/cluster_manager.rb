# frozen_string_literal: true

module Pharos
  class ClusterManager
    include Pharos::Logging

    attr_reader :config

    # @param config [Pharos::Config]
    # @param pastel [Pastel]
    def initialize(config, pastel: Pastel.new)
      @config = config
      @pastel = pastel
      @context = {}
    end

    # @return [Pharos::SSH::Manager]
    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end

    # @return [Pharos::AddonManager]
    def phase_manager
      @phase_manager = Pharos::PhaseManager.new(
        ssh_manager: ssh_manager,
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
      Pharos::PhaseManager.load_phases(__dir__ + '/phases/')
      addon_dirs = [
        File.join(__dir__, '..', '..', 'addons'),
        File.join(Dir.pwd, 'addons')
      ] + @config.addon_paths.map { |d| File.join(Dir.pwd, d) }
      Pharos::AddonManager.load_addons(*addon_dirs)
      Pharos::HostConfigManager.load_configs(@config)
    end

    def gather_facts
      apply_phase(Phases::GatherFacts, config.hosts, ssh: true, parallel: true)
    end

    def validate
      addon_manager.validate
      gather_facts
      apply_phase(Phases::ValidateHost, config.hosts, ssh: true, parallel: true)
    end

    # @return [Array<Pharos::Configuration::Host>]
    def sorted_master_hosts
      config.master_hosts.sort_by(&:master_sort_score)
    end

    # @return [Array<Pharos::Configuration::Host>]
    def sorted_etcd_hosts
      config.etcd_hosts.sort_by(&:etcd_sort_score)
    end

    def apply_phases
      # we need to use sorted masters because phases expects that first one has
      # ca etc config files
      master_hosts = sorted_master_hosts

      apply_phase(Phases::MigrateMaster, master_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureHost, config.hosts, ssh: true, parallel: true)

      unless @config.etcd&.endpoints
        # we need to use sorted etcd hosts because phases expects that first one has
        # ca etc config files
        etcd_hosts = sorted_etcd_hosts
        apply_phase(Phases::ConfigureCfssl, etcd_hosts, ssh: true, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, [etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, [etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcd, etcd_hosts, ssh: true, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::SetupMaster, master_hosts, ssh: true, parallel: true)
      apply_phase(Phases::UpgradeMaster, master_hosts, ssh: true, parallel: false)

      apply_phase(Phases::MigrateWorker, config.worker_hosts, ssh: true, parallel: true, master: master_hosts.first)
      apply_phase(Phases::ConfigureKubelet, config.hosts, ssh: true, parallel: true)

      apply_phase(Phases::ConfigureMaster, master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::ConfigureClient, [master_hosts.first], ssh: true, master: master_hosts.first, parallel: false)

      # master is now configured and can be used
      apply_phase(Phases::ConfigureDNS, [master_hosts.first], master: master_hosts.first)

      apply_phase(Phases::ConfigureWeave, [master_hosts.first], master: master_hosts.first) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico, [master_hosts.first], master: master_hosts.first) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureMetrics, [master_hosts.first], master: master_hosts.first)
      apply_phase(Phases::ConfigureBootstrap, [master_hosts.first], ssh: true) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, ssh: true, parallel: true)

      apply_phase(Phases::LabelNode, config.hosts, master: master_hosts.first, ssh: false, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe
    end

    def apply_reset
      apply_phase(Phases::ResetHost, config.hosts, ssh: true, parallel: true)
    end

    # @param phase_class [Pharos::Phase]
    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_phase(phase_class, hosts, **options)
      return if hosts.empty?

      puts @pastel.cyan("==> #{phase_class.title} @ #{hosts.join(' ')}")

      phase_manager.apply(phase_class, hosts, **options)
    end

    def apply_addons
      addon_manager.each do |addon|
        puts @pastel.cyan("==> #{addon.enabled? ? 'Enabling' : 'Disabling'} addon #{addon.name}")

        addon.apply
      end
    end

    def save_config
      master_host = sorted_master_hosts.first
      apply_phase(Phases::StoreClusterConfiguration, [master_host], master: master_host)
    end

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
