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

    # @param config [Pharos::Config]
    def initialize(config)
      @config = config
      @context = {
        'post_install_messages' => {}
      }
    end

    # @return [Pharos::PhaseManager]
    def phase_manager
      @phase_manager ||= Pharos::PhaseManager.new(
        config: @config,
        cluster_context: @context
      )
    end

    # load phases
    def load
      Pharos::PhaseManager.load_phases(*self.class.phase_dirs)
      Pharos::Host::Configurer.load_configurers
    end

    def gather_facts
      apply_phase(Phases::ConnectSSH, config.hosts.reject(&:local?), parallel: true)
      apply_phase(Phases::GatherFacts, config.hosts, parallel: true)
      apply_phase(Phases::ConfigureClient, [config.master_host], parallel: false)
      apply_phase(Phases::LoadClusterConfiguration, [config.master_host]) if config.master_host.master_sort_score.zero?
      apply_phase(Phases::ConfigureClusterName, %w(localhost))
    end

    def validate
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
      apply_phase(Phases::ConfigureClient, master_only, parallel: false)

      unless @config.etcd&.endpoints
        etcd_hosts = config.etcd_hosts
        apply_phase(Phases::ConfigureCfssl, etcd_hosts, parallel: true)
        apply_phase(Phases::ConfigureEtcdCa, [etcd_hosts.first], parallel: false)
        apply_phase(Phases::ConfigureEtcdChanges, [etcd_hosts.first], parallel: false)
        apply_phase(Phases::ConfigureEtcd, etcd_hosts, parallel: true)
      end

      apply_phase(Phases::ConfigureSecretsEncryption, master_hosts, parallel: false)
      apply_phase(Phases::SetupMaster, master_hosts, parallel: true)
      apply_phase(Phases::UpgradeMaster, master_hosts, parallel: false)

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
      apply_phase(Phases::ConfigureCloudProvider, master_only)
      apply_phase(Phases::ConfigureDNS, master_only)
      apply_phase(Phases::ConfigureWeave, master_only) if config.network.provider == 'weave'
      apply_phase(Phases::ConfigureCalico, master_only) if config.network.provider == 'calico'
      apply_phase(Phases::ConfigureCustomNetwork, master_only) if config.network.provider == 'custom'
      apply_phase(Phases::ConfigureKubeletCsrApprover, master_only)
      apply_phase(Phases::ConfigureHelmController, master_only)
      apply_phase(Phases::ConfigureBootstrap, master_only) # using `kubeadm token`, not the kube API

      apply_phase(Phases::JoinNode, config.worker_hosts, parallel: true)
      apply_phase(Phases::LabelNode, %w(localhost))

      # configure services that need workers
      apply_phase(Phases::ConfigureMetrics, master_only)

      apply_phase(Phases::ApplyManifests, master_only)
    end

    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_reset_hosts(hosts)
      master_hosts = config.master_hosts
      if master_hosts.first.master_sort_score.zero?
        apply_phase(Phases::Drain, hosts, parallel: false)
        apply_phase(Phases::DeleteHost, hosts, parallel: false)
      end
      apply_phase(Phases::ResetHost, hosts, parallel: true)
    end

    # @param phase_class [Pharos::Phase]
    # @param hosts [Array<Pharos::Configuration::Host>]
    def apply_phase(phase_class, hosts, **options)
      return if hosts.empty?

      puts "==> #{phase_class.title} @ #{hosts.join(' ')}".cyan

      phase_manager.apply(phase_class, hosts, **options)
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
