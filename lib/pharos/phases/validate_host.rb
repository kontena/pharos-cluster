# frozen_string_literal: true

require 'ipaddr'

module Pharos
  module Phases
    class ValidateHost < Pharos::Phase
      title "Validate hosts"

      def call
        logger.info { "Checking sudo access ..." }
        check_sudo
        logger.info { "Gathering host facts ..." }
        gather_host_facts
        logger.info { "Validating current role matches ..." }
        check_role
        logger.info { "Validating distro and version ..." }
        check_distro_version
        logger.info { "Validating host configuration ..." }
        check_cpu_arch
      end

      def check_distro_version
        @host.configurer(@ssh) # load configurer
        return if Pharos::Host::Configurer.configs.any? { |config| config.supported_os?(@host.os_release) }

        raise Pharos::InvalidHostError, "Distro not supported: #{@host.os_release.name}"
      end

      def check_cpu_arch
        return if @host.cpu_arch.supported?
        raise Pharos::InvalidHostError, "Cpu architecture not supported: #{@host.cpu_arch.id}"
      end

      def check_sudo
        @ssh.exec!('sudo -n true')
      rescue Pharos::SSH::RemoteCommand::ExecError => exc
        raise Pharos::InvalidHostError, "Unable to sudo: #{exc.output}"
      end

      def gather_host_facts
        @host.os_release = os_release
        @host.cpu_arch = cpu_arch
        @host.hostname = hostname
        @host.checks = host_checks
        @host.private_interface_address = private_interface_address(@host.private_interface) if @host.private_interface
        @host.resolvconf = read_resolvconf
        @host.routes = read_routes
      end

      def check_role
        return if !@host.checks['kubelet_configured']

        raise Pharos::InvalidHostError, "Cannot change worker host role to master" if @host.master? && !@host.checks['ca_exists']
        raise Pharos::InvalidHostError, "Cannot change master host role to worker" if @host.worker? && @host.checks['ca_exists']

        logger.debug { "#{@host.role} role matches" }
      end

      # @return [String]
      def hostname
        cloud_provider = @config.cloud&.provider
        if cloud_provider == 'aws'
          @ssh.exec!('hostname -f').strip
        else
          @ssh.exec!('hostname -s').strip
        end
      end

      # @return [Pharos::Configuration::OsRelease]
      def os_release
        os_info = {}
        @ssh.file('/etc/os-release').each_line do |line|
          match = line.match(/^(.+)=(.+)$/)
          os_info[match[1]] = match[2].delete('"') if match
        end
        Pharos::Configuration::OsRelease.new(
          id: os_info['ID'],
          id_like: os_info['ID_LIKE'] || os_info['ID'],
          name: os_info['PRETTY_NAME'],
          version: os_info['VERSION_ID']
        )
      end

      # @return [Pharos::Configuration::CpuArch]
      def cpu_arch
        cpu = {}
        @ssh.exec!('lscpu').split("\n").each do |line|
          match = line.match(/^(.+):\s+(.+)$/)
          cpu[match[1]] = match[2]
        end
        Pharos::Configuration::CpuArch.new(
          id: cpu['Architecture']
        )
      end

      # @return [Hash]
      def host_checks
        data = {}
        data['kubelet_configured'] = @ssh.file('/etc/kubernetes/kubelet.conf').exist?
        data['ca_exists'] = @ssh.file('/etc/kubernetes/pki/ca.key').exist?
        data['etcd_ca_exists'] = @ssh.file('/etc/pharos/pki/ca-key.pem').exist?

        if data['ca_exists']
          result = @ssh.exec("sudo curl -sSf --connect-timeout 1 --cacert /etc/kubernetes/pki/ca.crt https://localhost:6443/healthz")
          data['api_healthy'] = (result.success? && result.stdout == 'ok')
        end

        if data['etcd_ca_exists']
          etcd = Pharos::Etcd::Client.new(@ssh)
          data['etcd_healthy'] = etcd.healthy?
        end

        data
      end

      # @param interface [String]
      # @return [String]
      def private_interface_address(interface)
        @ssh.exec!("ip -o addr show dev #{interface} scope global").each_line do |line|
          _index, _dev, _family, addr = line.split
          ip, _prefixlen = addr.split('/')

          next if ip == @host.address

          return ip
        end
        nil
      end

      # @return [Array<String>]
      def read_resolvconf_nameservers
        nameservers = []

        @ssh.file('/etc/resolv.conf').each_line do |line|
          if match = line.match(/nameserver (.+)/)
            nameservers << match[1]
          end
        end

        nameservers
      end

      LOCALNET = IPAddr.new('127.0.0.0/8')

      # Host /etc/resolv.conf is configured to use a nameserver at localhost in the host network namespace
      # @return [Boolean]
      def check_resolvconf_nameserver_localhost
        resolvers = read_resolvconf_nameservers.map{ |ip| IPAddr.new(ip) }
        resolvers.any? { |ip| LOCALNET.include?(ip) }
      end

      # Host /etc/resolv.conf is configured to use the systemd-resolved stub resolver at 127.0.0.53
      # @return [Boolean]
      def check_resolvconf_systemd_resolved_stub
        symlink = @ssh.file('/etc/resolv.conf').readlink
        !!symlink && symlink.end_with?('/run/systemd/resolve/stub-resolv.conf')
      end

      # @return [Pharos::Configuration::Host::ResolvConf]
      def read_resolvconf
        Pharos::Configuration::Host::ResolvConf.new(
          nameserver_localhost: check_resolvconf_nameserver_localhost,
          systemd_resolved_stub: check_resolvconf_systemd_resolved_stub
        )
      end

      ROUTE_REGEXP = %r(^((?<type>\S+)\s+)?(?<prefix>default|[0-9./]+)(\s+via (?<via>\S+))?(\s+dev (?<dev>\S+))?(\s+proto (?<proto>\S+))?(\s+(?<options>.+))?$)

      # @return [Array<Pharos::Configuration::Host::Route>]
      def read_routes
        routes = []

        @ssh.exec!("ip route").each_line do |line|
          if match = ROUTE_REGEXP.match(line.strip)
            captures = Hash[match.named_captures.map{|k, v| [k.to_sym, v]}]
            captures[:prefix] = '0.0.0.0/0' if captures[:prefix] == 'default'

            route = Pharos::Configuration::Host::Route.new(raw: line.strip, **captures)

            logger.debug { "ip route: #{route.inspect}"}

            routes << route
          else
            logger.warn { "Unmatched `ip route` line: #{line.inspect}"}
          end
        end

        routes
      end
    end
  end
end
