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
      @hosts ||= Array(
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
      if command_list.empty?
        exit_statuses = hosts.map do |host|
          target = "#{host.user}@#{use_private? ? host.private_address : host.address}"
          puts pastel.green("==> Opening a session to #{target} ..") unless !$stdout.tty?
          system('ssh', '-i', host.ssh_key_path, target)
        end
        exit(1) unless exit_statuses.all?(&:itself)
      elsif hosts.size == 1
        result = ssh_manager.client_for(hosts.first).exec(command_list)
        puts result.output
        exit result.exit_status
      else
        threads = hosts.map do |host|
          Thread.new do
            begin
              [host, ssh_manager.client_for(host).exec(command_list)]
            rescue => ex
              [
                host,
                Pharos::SSH::RemoteCommand::Result.new.tap do |r|
                  r.output << "#{ex.message}"
                end
              ]
            end
          end
        end
        results = threads.map(&:value)
        results.each do |host, result|
          puts pastel.send(result.exit_status.zero? ? :green : :red, "==> Result from #{host.address}")
          puts result.output.gsub(/^/, "  ")
        end
        exit(1) if results.none? { |_, result| result.success? }
      end
    end

    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end
  end
end
