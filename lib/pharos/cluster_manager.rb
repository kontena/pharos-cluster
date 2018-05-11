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
        @config,
        ssh_manager: ssh_manager,
        cluster_context: @context
      )
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new(
        @config,
        cluster_context: @context,
      )
    end

    # load phases/addons
    def load
      Pharos::PhaseManager.load_phases(__dir__ + '/phases/')
      Pharos::AddonManager.load_addons(__dir__ + '/addons/')
    end

    def validate
      addon_manager.validate
      apply_phase(Phases::ValidateHost, config.hosts, ssh: true, parallel: true)
      apply_phase(Phases::ValidateHostname, config.hosts, ssh: false, parallel: false)
    end

    def apply_phases
      apply_phase(Phases::MigrateMaster, config.master_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureHost, config.hosts, ssh: true, parallel: true)

      if config.etcd_hosts?
        apply_phase(Phases::ConfigureCfssl, config.etcd_hosts, ssh: true, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, [config.etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, [config.etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcd, config.etcd_hosts, ssh: true, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, config.sorted_master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::ConfigureMaster, config.sorted_master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::MigrateWorker, config.worker_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureKubelet, config.worker_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureClient, [config.master_host], ssh: true, parallel: false)

      # master is now configured and can be used
      apply_phase(Phases::FetchClusterConfiguration, [config.master_host], kube: true)
      apply_phase(Phases::ConfigureDNS, [config.master_host], kube: true)
      apply_phase(Phases::ConfigureWeave, [config.master_host], kube: true) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico, [config.master_host], kube: true) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureMetrics, [config.master_host], kube: true)
      apply_phase(Phases::ConfigureBootstrap, [config.master_host], ssh: true) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, ssh: true, parallel: true)

      apply_phase(Phases::LabelNode, config.hosts, kube: true, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe
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
      apply_phase(Phases::StoreClusterConfiguration, [config.master_host], kube: true)
    end

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
