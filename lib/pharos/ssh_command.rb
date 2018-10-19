# frozen_string_literal: true

module Pharos
  class SSHCommand < Pharos::Command
    include HostFilterOptions

    usage "[OPTIONS] -- [COMMANDS] ..."
    parameter "[COMMAND] ...", "Run command on host"

    banner "Opens SSH sessions to hosts in the Kontena Pharos cluster."

    def execute
      exit run_interactive if command_list.empty?
      exit run_single(hosts.first) if hosts.size == 1
      exit run_parallel
    end

    private

    def run_interactive
      exit_statuses = filtered_hosts.map do |host|
        target = "#{host.user}@#{host.address}"
        puts pastel.green("==> Opening a session to #{target} ..") unless !$stdout.tty?
        system('ssh', '-i', host.ssh_key_path, target)
      end
      exit_statuses.all?(&:itself) ? 0 : 1
    end

    def run_single(host)
      result = ssh_manager.client_for(host).exec(command_list)
      puts result.output
      result.exit_status
    end

    def run_parallel
      threads = filtered_hosts.map do |host|
        Thread.new do
          begin
            [host, ssh_manager.client_for(host).exec(command_list)]
          rescue StandardError => ex
            [
              host,
              Pharos::SSH::RemoteCommand::Result.new.tap do |r|
                r.output << ex.message
              end
            ]
          end
        end
      end
      results = threads.map(&:value)
      results.each do |host, result|
        puts pastel.send(result.exit_status.zero? ? :green : :red, "==> Result from #{host.user}@#{host.address}")
        puts result.output.gsub(/^/, "  ")
      end
      results.all? { |_, result| result.success? } ? 0 : 1
    end

    def ssh_manager
      @ssh_manager ||= Pharos::SSH::Manager.new
    end
  end
end
