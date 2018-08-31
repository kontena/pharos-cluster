# frozen_string_literal: true

module Pharos
  class SSHCommand < UpCommand
    usage "[OPTIONS] -- [COMMANDS] ..."
    parameter "[COMMANDS] ...", "Run command on host"

    banner "Opens an SSH session to a host in the Kontena Pharos cluster. If no filtering parameters are given, the first host is used."

    option ['-r', '--role'], 'ROLE', 'select a server by role'
    option ['-l', '--label'], 'LABEL=VALUE', 'select a server by label, can be specified multiple times', multivalued: true do |pair|
      Hash[*[:key, :value].zip(pair.split('=', 2))]
    end
    option ['-a', '--address'], 'ADDRESS', 'select a server by public address'
    option ['-p', '--private-address'], 'ADDRESS', 'select a server by private address'

    option ['-P', '--use-private'], :flag, 'connect to the private address'

    def host
      @host ||= load_config.hosts.find do |host|
        next if role && host.role != role
        next if address && host.address != address
        next if private_address && host.private_address != private_address

        unless label_list.empty?
          next unless label_list.all? { |l| host.labels[l[:key]] == l[:value] }
        end

        true
      end
    end

    def execute
      if host
        target = "#{host.user}@#{use_private? ? host.private_address : host.address}"
        puts pastel.green("==> Opening a session to #{target} ..") unless !$stdout.tty?
        cmd = ['ssh', "-i", host.ssh_key_path, target]

        unless commands_list.empty?
          cmd << '--'
          cmd.concat(commands_list)
        end

        puts "Executing #{cmd.inspect}" if debug?

        exec(*cmd)
      else
        signal_usage_error 'no host matched in configuration'
      end
    end
  end
end
