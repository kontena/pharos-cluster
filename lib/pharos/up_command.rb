# frozen_string_literal: true

module Pharos
  class UpCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    options :load_config, :tf_json, :yes?

    option ['-n', '--name'], 'NAME', 'use as cluster name', attribute_name: :new_name
    option ['-f', '--force'], :flag, "force upgrade"
    option ['--trust-hosts'], :flag, "remove hosts from ~/.ssh/known_hosts before connecting"

    def execute
      puts "==> KONTENA PHAROS v#{Pharos.version} (Kubernetes v#{Pharos::KUBE_VERSION})".bright_green

      Pharos::Kube.init_logging!

      config = load_config
      config.attributes[:name] = new_name if new_name
      if trust_hosts?
        config.hosts.each do |host|
          `ssh-keygen -R #{host.address}`
        end
      end

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        configure(config)
      end
    end

    # @param config [Pharos::Config]
    # @param config_content [String]
    def configure(config)
      start_time = Time.now

      manager = cluster_manager('force' => force?)
      show_component_versions(config)
      prompt_continue(config, manager.context)

      puts "==> Starting to craft cluster ...".green
      manager.apply_phases

      manager.save_config

      craft_time = Time.now - start_time
      puts "==> Cluster has been crafted! (took #{humanize_duration(craft_time.to_i)})".green
      manager.post_install_messages.each do |component, message|
        puts "    Post-install message from #{component}:"
        message.lines.each do |line|
          puts "      #{line}"
        end
      end
      puts "    To configure kubectl for connecting to the cluster, use:"
      puts "      #{File.basename($PROGRAM_NAME)} kubeconfig #{"#{@config_options.join(' ')} " if @config_options} -n #{config.name} > kubeconfig"
      puts "      export KUBECONFIG=./kubeconfig"
      manager.disconnect
    end

    # @param config [Pharos::Config]
    def show_component_versions(config)
      puts "==> Using following software versions:".green
      Pharos::Phases.components_for_config(config).sort_by(&:name).each do |c|
        if c.os_release
          " (#{c.os_release.id} #{c.os_release.version})"
        else
          target = ""
        end
        puts "    #{c.name}: #{c.version}#{target}"
      end
    end

    # @param config [Pharos::Config]
    # @param existing_version [String]
    def prompt_continue(config, context)
      existing_version = context['existing-pharos-version']
      lexer = Rouge::Lexers::YAML.new
      puts "==> Configuration is generated and shown below:".green
      if color?
        puts rouge.format(lexer.lex(config.to_yaml.delete_prefix("---\n")))
        puts ""
      else
        puts config.to_yaml.delete_prefix("---\n")
      end

      if existing_version && Pharos.version != existing_version
        puts
        puts "Cluster is currently running Kontena Pharos version #{existing_version} and will be upgraded to #{Pharos.version}".yellow
        if context['unsafe_upgrade']
          if force?
            puts
            puts "WARNING:".red + " using --force to attempt an unsafe upgrade to version #{Pharos.version}."
          else
            error_message = <<~ERROR_MSG
              Upgrading to version #{Pharos.version} might not work (see https://www.pharos.sh/docs/upgrade.html).
              You may force the upgrade by running the command with --force.
            ERROR_MSG
            signal_error error_message
          end
        end
        puts
      end

      confirm_yes!('Continue?', default: true)
    end
  end
end
