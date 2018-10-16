# frozen_string_literal: true

module Pharos
  class SSHCommand < UpCommand
    usage "[OPTIONS] -- [COMMANDS] ..."
    parameter "[COMMAND] ...", "Run command on host"

    banner "Opens SSH sessions to hosts in the Kontena Pharos cluster."

    option ['-r', '--role'], 'ROLE', 'select a server by role'
    option ['-l', '--label'], 'LABEL=VALUE', 'select a server by label, can be specified multiple times', multivalued: true do |pair|
      Hash[*[:key, :value].zip(pair.split('=', 2))]
    end
    option ['-a', '--address'], 'ADDRESS', 'select a server by public address'

    option ['-P', '--use-private'], :flag, 'connect to the private address'
    option ['-f', '--first'], :flag, 'only perform on the first matching host'

    def hosts
      Array(
        load_config.hosts.send(first? ? :find : :select) do |host|
          next if role && host.role != role
          next if address && host.address != address

          unless label_list.empty?
            next unless label_list.all? { |l| host.labels[l[:key]] == l[:value] }
          end

          true
        end
      ).tap do |result|
        signal_usage_error 'no host matched in configuration' if result.empty?
      end
    end

    def execute
      exit_statuses = hosts.map do |host|
        target = "#{host.user}@#{use_private? ? host.private_address : host.address}"
        puts pastel.green("==> Opening a session to #{target} ..") unless !$stdout.tty?
        cmd = ['ssh', "-i", host.ssh_key_path, target]

        unless command_list.empty?
          cmd << '--'
          cmd.concat(command_list)
        end

        puts "Executing #{cmd.inspect}" if debug?

        system(*cmd)
      end
      exit(1) unless exit_statuses.all?(&:itself)
    end
  end
end
