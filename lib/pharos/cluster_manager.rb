# frozen_string_literal: true

require 'pathname'

module Pharos
  class ClusterManager
    include Pharos::Logging

    attr_reader :config, :ssh_manager, :addon_manager, :phase_manager, :context, :pastel

    # @param config [Pharos::Config]
    # @param pastel [Pastel]
    def initialize(config, pastel: Pastel.new)
      @config = config
      @pastel = pastel
      @context = { 'all_hosts' => @config.hosts }
      @ssh_manager = Pharos::SSH::Manager.new
      @phase_manager = Pharos::PhaseManager.new(cluster_manager: self)
      @addon_manager = Pharos::AddonManager.new(cluster_manager: self)
    end

    # load phases/addons
    def load
      Pharos::PhaseManager.load_phases(
        File.join(__dir__, 'phases'),
        File.join(__dir__, '..', '..', 'non-oss', 'phases')
      )
      addon_dirs = [
        File.join(__dir__, '..', '..', 'addons'),
        File.join(Dir.pwd, 'addons'),
        File.join(__dir__, '..', '..', 'non-oss', 'addons')
      ] + config.addon_paths.map { |d| File.join(Dir.pwd, d) }
      addon_dirs.keep_if { |dir| File.exist?(dir) }
      addon_dirs = addon_dirs.map { |dir| Pathname.new(dir).realpath.to_s }.uniq

      Pharos::AddonManager.load_addons(*addon_dirs)
      Pharos::HostConfigManager.load_configs(config)
    end

    def gather_facts
      apply_phase(Phases::GatherFacts)
    end

    def validate
      addon_manager.validate
      gather_facts
      update_context_hosts
      apply_phase(Phases::ValidateHost)
      apply_phase(Phases::ValidateVersion)
    end

    def update_context_hosts
      context['master_hosts'] = config.master_hosts.sort_by(&:master_sort_score)
      context['master'] = @context['master_hosts'].first
      context['etcd_hosts'] = config.etcd_hosts.sort_by(&:etcd_sort_score)
      context['etcd_master'] = @context['etcd_hosts'].first
      context['worker_hosts'] = config.worker_hosts
    end

    def apply_phases
      apply_phase(Phases::MigrateMaster)
      apply_phase(Phases::ConfigureHost)
      apply_phase(Phases::ConfigureClient)

      unless @config.etcd&.endpoints
        # we need to use sorted etcd hosts because phases expects that first one has
        # ca etc config files
        apply_phase(Phases::ConfigureCfssl)
        apply_phase(Phases::ConfigureEtcdCa)
        apply_phase(Phases::ConfigureEtcdChanges)
        apply_phase(Phases::ConfigureEtcd)
      end

      apply_phase(Phases::ConfigureSecretsEncryption)
      apply_phase(Phases::SetupMaster)
      apply_phase(Phases::UpgradeMaster)

      apply_phase(Phases::MigrateWorker)
      apply_phase(Phases::ConfigureKubelet)

      apply_phase(Phases::ConfigureMaster)
      apply_phase(Phases::ConfigureClient)

      # master is now configured and can be used
      apply_phase(Phases::LoadClusterConfiguration)
      apply_phase(Phases::ConfigureDNS)

      apply_phase(Phases::ConfigureWeave) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureMetrics)
      apply_phase(Phases::ConfigureTelemetry)
      apply_phase(Phases::ConfigureBootstrap) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode)

      apply_phase(Phases::LabelNode) # NOTE: uses the @master kube API for each node, not threadsafe
    end

    def apply_reset
      apply_phase(Phases::ResetHost)
    end

    # @param phase_class [Pharos::Phase]
    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_phase(phase_class)
      phase_manager.apply(phase_class)
    end

    def apply_addons
      addon_manager.each do |addon|
        puts @pastel.cyan("==> #{addon.enabled? ? 'Enabling' : 'Disabling'} addon #{addon.name}")

        addon.apply
      end
    end

    def save_config
      apply_phase(Phases::StoreClusterConfiguration)
    end

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
