# frozen_string_literal: true

require 'set'

module Pharos
  module Host
    class Configurer
      attr_reader :host, :config

      SCRIPT_LIBRARY = File.join(__dir__, '..', 'scripts', 'pharos.sh').freeze

      # @param host [Pharos::Configuration::Host]
      # @param config [Pharos::Config]
      def initialize(host, config = nil)
        @host = host
        @config = config
      end

      def ssh
        @ssh ||= host.ssh
      end

      def install_essentials
        abstract_method!
      end

      def configure_repos
        abstract_method!
      end

      def configure_netfilter
        abstract_method!
      end

      def configure_cfssl
        abstract_method!
      end

      # @return [Array<String>]
      def kubelet_args
        []
      end

      # @param args [Hash]
      def ensure_kubelet(args) # rubocop:disable Lint/UnusedMethodArgument
        abstract_method!
      end

      # @param args [Hash]
      def install_kube_packages(args) # rubocop:disable Lint/UnusedMethodArgument
        abstract_method!
      end

      # @param version [String]
      def upgrade_kubeadm(version) # rubocop:disable Lint/UnusedMethodArgument
        abstract_method!
      end

      def configure_container_runtime
        abstract_method!
      end

      def reset
        abstract_method!
      end

      # @param path [Array]
      # @return [String]
      def script_path(*path)
        File.join(__dir__, host.os_release.id, 'scripts', *path)
      end

      # @return [String]
      def script_library_install_path
        "/usr/local/share/pharos"
      end

      def configure_script_library
        ssh.exec("sudo mkdir -p #{script_library_install_path}")
        ssh.file("#{script_library_install_path}/util.sh").write(
          File.read(SCRIPT_LIBRARY)
        )
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        ssh.exec_script!(
          script,
          env: vars,
          path: script_path(script)
        )
      end

      def crio?
        @host.crio?
      end

      def docker?
        @host.docker?
      end

      # @return [Set]
      def self.configurers
        @configurers ||= Set.new
      end

      # @param os_release [String,Pharos::Configuration::OsRelease] os release such as "ubuntu" or an instance of Pharos::Configuration::OsRelease
      # @param os_version [String,NilClass] os_version, such as "16.04", needed when os_release is not an instance of Pharos::Configuration::OsRelease
      def self.for_os_release(os_release, os_version = nil)
        unless os_release.is_a?(Pharos::Configuration::OsRelease)
          os_release = Pharos::Configuration::OsRelease.new(id: os_release, version: os_version)
        end

        configurers.find { |c| c.supported?(os_release) }
      end

      def custom_docker?
        @host.custom_docker?
      end

      # @return [Pharos::Config,NilClass]
      def cluster_config
        self.class.cluster_config
      end

      # @return [Pharos::SSH::File]
      def env_file
        ssh.file('/etc/environment')
      end

      # Updates the environment file with values from existing environment file and host environment-configuration
      def update_env_file
        return if @host.environment.nil? || @host.environment.empty?

        host_env_file = env_file
        original_data = {}
        if host_env_file.exist?
          host_env_file.read.lines.each do |line|
            line.strip!
            next if line.start_with?('#')
            key, val = line.split('=', 2)
            val = nil if val.to_s.empty?
            original_data[key] = val
          end
        end

        new_content = @host.environment.merge(original_data) { |_key, old_val, _new_val| old_val }.compact.map do |key, val|
          "#{key}=#{val}"
        end.join("\n")
        new_content << "\n" unless new_content.end_with?("\n")

        host_env_file.write(new_content)
        ssh.disconnect; ssh.connect # reconnect to reread env
      end

      # @return [Array]
      def self.supported_os_releases
        @supported_os_releases ||= []
      end

      # Registers the configurer and its os/version to Pharos::Host::Configurer.configurers
      # @param os_name [String]
      # @param version [String]
      def self.register_config(os_name, version)
        supported_os_releases << Pharos::Configuration::OsRelease.new(id: os_name, version: version)
        Pharos::Host::Configurer.configurers << self
      end

      # @param os_release [String,Pharos::Configuration::OsRelease]
      # @param version [String,NilClass] needed when the os_release is not an instance of Pharos::Configuration::OsRelease
      def self.supported?(os_release, version = nil)
        unless os_release.is_a?(Pharos::Configuration::OsRelease)
          os_release = Pharos::Configuration::OsRelease.new(id: os_release, version: version)
        end

        supported_os_releases.include?(os_release)
      end

      # Registers a component to Pharos::Phases.components
      # @param component [Hash]
      def self.register_component(component)
        supported_os_releases.each do |os_release|
          component[:os_release] = os_release
          Pharos::Phases.register_component(component)
        end
      end

      private

      def abstract_method!
        raise NotImplementedError, 'This is an abstract base method. Implement in your subclass.'
      end
    end
  end
end

Dir.glob(File.join(__dir__, '**', '*.rb')).each { |f| require(f) }
