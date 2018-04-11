# frozen_string_literal: true

module Pharos
  class ClusterManager
    include Pharos::Logging

    # XXX: should be in some kind of output helper?
    def pastel
      @pastel ||= Pastel.new
    end

    attr_reader :config

    def initialize(config)
      @config = config
    end

    # @return [Pharos::SSH::Manager]
    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end

    # @return [Pharos::AddonManager]
    def phase_manager
      @phase_manager = Pharos::PhaseManager.new([__dir__ + '/phases/'],
        ssh_manager: ssh_manager,
        config: @config,
      )
    end

    # @return [Pharos::AddonManager]
    def addon_manager
      @addon_manager ||= Pharos::AddonManager.new([__dir__ + '/addons/'])
    end

    # preload code
    def preload
      phase_manager # triggers load_phases
      addon_manager # triggers load_addons
    end

    def validate
      addon_manager.validate(config.addons || {})
    end

    def up
      apply_phases
      apply_addons
    end

    def apply_phases
      apply_phase(Phases::ValidateHost, config.hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureHost, config.hosts, ssh: true, parallel: true)

      apply_phase(Phases::ConfigureKubelet, config.worker_hosts, ssh: true, parallel: true) # TODO: also run this phase in parallel for the master nodes, if not doing an upgrade?

      apply_phase(Phases::ConfigureMaster, config.master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::ConfigureClient, config.master_hosts, ssh: true, parallel: true)

      # master is now configured and can be used
      apply_phase(Phases::ConfigureDNS, [config.master_host], master: config.master_host)
      apply_phase(Phases::ConfigureNetwork, [config.master_host], master: config.master_host)
      apply_phase(Phases::ConfigureMetrics, [config.master_host], master: config.master_host)
      apply_phase(Phases::StoreClusterYAML, [config.master_host], master: config.master_host, config_content: config_yaml.read(ENV.to_h))
      apply_phase(Phases::ConfigureBootstrap, [config.master_host], ssh: true) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, ssh: true, parallel: true)

      apply_phase(Phases::LabelNode, config.hosts, master: config.master_host, ssh: false, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe
    end

    def apply_phase(phase_class, hosts, **options)
      puts pastel.cyan("==> #{phase_class.title} @ #{hosts.join(' ')}")

      phase_manager.apply(phase_class, hosts, **options)
    end

    def apply_addons
      puts pastel.cyan("==> addons: #{master.address}")

      addon_manager.apply(config.master_host, config.addons)
    end

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
