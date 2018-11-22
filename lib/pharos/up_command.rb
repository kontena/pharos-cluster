# frozen_string_literal: true

module Pharos
  class UpCommand < Pharos::Command
    options :load_config, :yes?

    option ['-f', '--force'], :flag, "force upgrade"
    STRIP_OPTIONS = %w(-y --yes -d --debug -f --force).freeze

    def execute
      puts pastel.bright_green("==> KONTENA PHAROS v#{Pharos.version} (Kubernetes v#{Pharos::KUBE_VERSION})")

      Pharos::Kube.init_logging!

      config = load_config

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        configure(config)
      end
    end

    # @param config [Pharos::Config]
    # @param config_content [String]
    def configure(config)
      manager = ClusterManager.new(config, pastel: pastel)
      start_time = Time.now

      manager.context['force'] = force?

      puts pastel.green("==> Sharpening tools ...")
      manager.load
      manager.validate
      show_component_versions(config)
      show_addon_versions(manager)
      manager.apply_addons_cluster_config_modifications
      prompt_continue(config, manager.context)

      puts pastel.green("==> Starting to craft cluster ...")
      manager.apply_phases

      puts pastel.green("==> Configuring addons ...")
      manager.apply_addons

      manager.save_config

      craft_time = Time.now - start_time
      defined_opts = (ARGV[1..-1] - STRIP_OPTIONS).join(" ")
      defined_opts += " " unless defined_opts.empty?
      puts pastel.green("==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})")
      manager.post_install_messages.each do |component, message|
        puts "    Post-install message from #{component}:"
        message.lines.each do |line|
          puts "      #{line}"
        end
      end
      puts "    To configure kubectl for connecting to the cluster, use:"
      puts "      #{File.basename($PROGRAM_NAME)} kubeconfig #{defined_opts}> kubeconfig"
      puts "      export KUBECONFIG=./kubeconfig"
      manager.disconnect
    end

    # @param config [Pharos::Config]
    def show_component_versions(config)
      puts pastel.green("==> Using following software versions:")
      Pharos::Phases.components_for_config(config).sort_by(&:name).each do |c|
        if c.os_release
          " (#{c.os_release.id} #{c.os_release.version})"
        else
          target = ""
        end
        puts "    #{c.name}: #{c.version}#{target}"
      end
    end

    def show_addon_versions(manager)
      puts pastel.green("==> Using following addons:")
      manager.addon_manager.with_enabled_addons do |addon|
        puts "    #{addon.addon_name}: #{addon.version}"
      end
    end

    # @param config [Pharos::Config]
    # @param existing_version [String]
    def prompt_continue(config, context)
      existing_version = context['existing-pharos-version']
      lexer = Rouge::Lexers::YAML.new
      puts pastel.green("==> Configuration is generated and shown below:")
      if color?
        puts rouge.format(lexer.lex(config.to_yaml))
        puts ""
      else
        puts config.to_yaml
      end

      if existing_version && Pharos.version != existing_version
        puts
        puts pastel.yellow("Cluster is currently running Kontena Pharos version #{existing_version} and will be upgraded to #{Pharos.version}")
        if context['unsafe_upgrade']
          if force?
            puts
            puts pastel.red("WARNING:") + " using --force to attempt an unsafe upgrade, this can break your cluster."
          else
            signal_error "Unsupported upgrade path. You may try to force the upgrade by running\n" \
                         "the command with --force or use the Kontena Pharos Pro version."
          end
        end
        puts
      end

      confirm_yes!('Continue?', default: true)
    end
  end
end
