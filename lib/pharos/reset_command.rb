# frozen_string_literal: true

module Pharos
  class ResetCommand < UpCommand

    def execute
      puts pastel.bright_green("==> KONTENA PHAROS v#{Pharos::VERSION} (Kubernetes v#{Pharos::KUBE_VERSION})")
      config = load_config

      # set workdir to the same dir where config was loaded from
      # so that the certs etc. can be referenced more easily
      Dir.chdir(config_yaml.dirname) do
        reset(config)
      end
    rescue Pharos::ConfigError => exc
      warn "==> #{exc}"
      exit 11
    rescue StandardError => ex
      raise unless ENV['DEBUG'].to_s.empty?
      warn "#{ex.class.name} : #{ex.message}"
      exit 1
    end

    # @param config [Pharos::Config]
    # @param config_content [String]
    def reset(config)
      manager = ClusterManager.new(config, pastel: pastel)
      start_time = Time.now

      puts pastel.green("==> Sharpening tools ...")
      manager.load
      manager.validate

      if $stdin.tty? && !yes?
        exit 1 unless prompt.yes?(pastel.red('Do you really want to reset (it will wipe configuration & data from all hosts)?'))
      end

      puts pastel.green("==> Starting to reset cluster ...")
      manager.apply_reset
      reset_time = Time.now - start_time
      puts pastel.green("==> Cluster has been reset! (took #{humanize_duration(reset_time.to_i)})")

      manager.disconnect
    end
  end
end
