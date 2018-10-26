# frozen_string_literal: true

module Pharos
  class SSHCommand < Pharos::Command
    options :filtered_hosts

    usage "[OPTIONS] -- [COMMANDS] ..."
    parameter "[COMMAND] ...", "Run command on host"

    banner "Opens SSH sessions to hosts in the Kontena Pharos cluster."

    def execute
      if command_list.empty?
        signal_usage_error 'interactive mode can not be used with a non-interactive terminal' unless $stdin.tty? && $stdout.tty?
        run_interactive
        exit 0
      end

      exit run_single(filtered_hosts.first) if filtered_hosts.size == 1
      exit run_parallel
    end

    private

    def run_interactive
      filtered_hosts.map do |host|
        target = "#{host.user}@#{host.address}"
        puts pastel.green("==> Opening a session to #{target} ..")
        ssh_manager.client_for(host).interactive_session
      end
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
