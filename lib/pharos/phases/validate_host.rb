# frozen_string_literal: true

require_relative 'logging'

module Pharos
  module Phases
    class ValidateHost
      include Pharos::Phases::Logging

      # @param host [Pharos::Configuration::Host]
      def initialize(host)
        @host = host
      end

      def call
        logger.info(@host.address) { "Connecting to host via SSH ..." }
        ssh = Pharos::SSH::Client.for_host(@host)
        logger.info { "Checking sudo access ..." }
        check_sudo(ssh)
        logger.info { "Gathering host facts ..." }
        gather_host_facts(ssh)
        logger.info { "Validating distro and version ..." }
        check_distro_version
        logger.info { "Validating host configuration ..." }
        check_cpu_arch
      end

      def check_distro_version
        return if @host.os_release.supported?
        raise Pharos::InvalidHostError, "Distro not supported: #{@host.os_release.name}"
      end

      def check_cpu_arch
        return if @host.cpu_arch.supported?
        raise Pharos::InvalidHostError, "Cpu architecture not supported: #{@host.cpu_arch.id}"
      end

      def check_sudo(ssh)
        ssh.exec!('sudo -n true')
      rescue Pharos::SSH::ExecError => exc
        raise Pharos::InvalidHostError, "Unable to sudo: #{exc.output}"
      end

      # @param ssh [Pharos::SSH::Client]
      def gather_host_facts(ssh)
        @host.os_release = os_release(ssh)
        @host.cpu_arch = cpu_arch(ssh)
        @host.hostname = ssh.exec!('hostname -f').strip
      end

      # @param ssh [Pharos::SSH::Client]
      # @return [Pharos::Configuration::OsRelease]
      def os_release(ssh)
        os_info = {}
        ssh.read_file('/etc/os-release').split("\n").each do |line|
          match = line.match(/^(.+)=(.+)$/)
          os_info[match[1]] = match[2].delete('"')
        end
        Pharos::Configuration::OsRelease.new(
          id: os_info['ID'],
          id_like: os_info['ID_LIKE'],
          name: os_info['PRETTY_NAME'],
          version: os_info['VERSION_ID']
        )
      end

      # @param ssh [Pharos::SSH::Client]
      # @return [Pharos::Configuration::CpuArch]
      def cpu_arch(ssh)
        cpu = {}
        ssh.exec!('lscpu').split("\n").each do |line|
          match = line.match(/^(.+):\s+(.+)$/)
          cpu[match[1]] = match[2]
        end
        Pharos::Configuration::CpuArch.new(
          id: cpu['Architecture']
        )
      end
    end
  end
end
