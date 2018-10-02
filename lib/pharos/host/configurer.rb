# frozen_string_literal: true

require 'set'

module Pharos
  module Host
    class Configurer
      attr_reader :host, :ssh, :config

      SCRIPT_LIBRARY = File.join(__dir__, '..', 'scripts', 'pharos.sh').freeze

      def initialize(host, config = nil)
        @host = host
        @config = config
        @ssh = host.ssh
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
        @ssh.exec("sudo mkdir -p #{script_library_install_path}")
        @ssh.file("#{script_library_install_path}/util.sh").write(
          File.read(SCRIPT_LIBRARY)
        )
      end

      # @param script [String] name of file under ../scripts/
      def exec_script(script, vars = {})
        @ssh.exec_script!(
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

      def self.configurers
        @configurers ||= Set.new
      end

      def self.for_os_release(os_release, os_version = nil)
        unless os_release.is_a?(Pharos::Configuration::OsRelease)
          os_release = Pharos::Configuration::OsRelease.new(id: os_release, version: os_version)
        end

        configurers.find { |c| c.supported?(os_release) }
      end

      def self.supported_os_releases
        @supported_os_releases ||= []
      end

      # @param os [String]
      # @param version [String]
      def self.register_config(os, version)
        supported_os_releases << Pharos::Configuration::OsRelease.new(id: os, version: version)
        Pharos::Host::Configurer.configurers << self
      end

      def self.supported?(os_release, version = nil)
        unless os_release.kind_of?(Pharos::Configuration::OsRelease)
          os_release = Pharos::Configuration::OsRelease.new(id: os_release, version: version)
        end

        supported_os_releases.include?(os_release)
      end

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
