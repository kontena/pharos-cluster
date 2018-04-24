# frozen_string_literal: true

module Pharos
  class ClusterManager
    include Pharos::Logging

    attr_reader :config

    def initialize(config, config_content:, **opts)
      @config = config
      @config_content = config_content
      @pastel = opts.fetch(:pastel) { Pastel.new }
    end

    # @return [Pharos::SSH::Manager]
    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end

    # @return [Pharos::AddonManager]
    def phase_manager
      @phase_manager = Pharos::PhaseManager.new(
        ssh_manager: ssh_manager,
        config: @config
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

    # @return [Array<Pharos::Configuration::Host>]
    def sorted_master_hosts
      @sorted_master_hosts ||= config.master_hosts.sort_by { |h| master_sort_score(h) }
    end

    # @param host [Pharos::Configuration::Host]
    # @return [Integer]
    def master_sort_score(host)
      score = 0
      return score if host.checks['api_healthy']
      score += 1
      return score if host.checks['kubelet_configured']

      score + 1
    end

    # @return [Array<Pharos::Configuration::Host>]
    def sorted_etcd_hosts
      @sorted_etcd_hosts ||= config.etcd_hosts.sort_by { |h| etcd_sort_score(h) }
    end

    # @param host [Pharos::Configuration::Host]
    # @return [Integer]
    def etcd_sort_score(host)
      score = 0
      return score if host.checks['etcd_healthy']
      score += 1
      return score if host.checks['etcd_ca_exists']

      score + 1
    end

    def apply_phases
      apply_phase(Phases::ValidateHost, config.hosts, ssh: true, parallel: true)

      master_hosts = sorted_master_hosts

      apply_phase(Phases::MigrateMaster, master_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureHost, config.hosts, ssh: true, parallel: true)

      unless @config.etcd&.hosts
        etcd_hosts = sorted_etcd_hosts
        apply_phase(Phases::ConfigureCfssl, etcd_hosts, ssh: true, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, [etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, [etcd_hosts.first], ssh: true, parallel: false)
        apply_phase(Phases::ConfigureEtcd, etcd_hosts, ssh: true, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::ConfigureMaster, master_hosts, ssh: true, parallel: false)
      apply_phase(Phases::MigrateWorker, config.worker_hosts, ssh: true, parallel: true, master: master_hosts.first)
      apply_phase(Phases::ConfigureKubelet, config.worker_hosts, ssh: true, parallel: true)
      apply_phase(Phases::ConfigureClient, [master_hosts.first], ssh: true, parallel: false)

      # master is now configured and can be used
      apply_phase(Phases::ConfigureDNS, [master_hosts.first], master: master_hosts.first)
 
      apply_phase(Phases::ConfigureWeave, [master_hosts.first], master: master_hosts.first) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico, [master_hosts.first], master: master_hosts.first) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureMetrics, [master_hosts.first], master: master_hosts.first)
      apply_phase(Phases::StoreClusterYAML, [master_hosts.first], master: master_hosts.first, config_content: @config_content)
      apply_phase(Phases::ConfigureBootstrap, [master_hosts.first], ssh: true) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, ssh: true, parallel: true)

      apply_phase(Phases::LabelNode, config.hosts, master: master_hosts.first, ssh: false, parallel: false) # NOTE: uses the @master kube API for each node, not threadsafe
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

    def disconnect
      ssh_manager.disconnect_all
    end
  end
end
