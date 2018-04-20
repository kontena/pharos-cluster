# frozen_string_literal: true

module Pharos
  class ClusterManager
    include Pharos::Logging

    attr_reader :config

    def initialize(config, **options)
      @config = config
      @pastel = options.fetch(:pastel) { Pastel.new }
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
        master: @config.master_host
      )
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new(@config)
    end

    # load phases/addons
    def load
      Pharos::PhaseManager.load_phases(__dir__ + '/phases/')
      Pharos::AddonManager.load_addons(__dir__ + '/addons/')
    end

    def validate
      addon_manager.validate
    end

    def apply_phases
      [
        :ValidateHost,
        :MigrateMaster,
        :ConfigureHost,
        :ConfigureCfssl,
        :ConfigureEtcdCa,
        :ConfigureEtcd,

        :ConfigureSecretsEncryption,
        :ConfigureMaster,
        :MigrateWorker,
        :ConfigureKubelet, # TODO: also run this phase in parallel for the master nodes, if not doing an upgrade?
        :ConfigureClient,

        # master is now configured and can be used
        :ConfigureDNS,
        :ConfigureNetwork,
        :ConfigureMetrics,
        :StoreClusterYAML,
        :ConfigureBootstrap, # using `kubeadm token`, not the kube API

        :JoinNode,

        :LabelNode # NOTE: uses the @master kube API for each node, not threadsafe
      ].each do |phase|
        apply_phase(Phases.const_get(phase))
      end
    end

    def apply_phase(phase_class)
      hosts = Array(config.send(phase_class.runs_on))
      return if hosts.empty?

      puts @pastel.cyan("==> #{phase_class.title} @ #{phase_class.runs_on}")

      phase_manager.apply(phase_class, hosts)
    end

    def apply_addons
      addon_manager.each do |addon|
        puts @pastel.cyan("==> #{addon.enabled? ? 'Enabling' : 'Disabling'} addon #{addon.name}")

        addon.apply
      end
    end

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
