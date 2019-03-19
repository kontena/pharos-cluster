# frozen_string_literal: true

module Pharos
  class ExecCommand < Pharos::Command
    using Pharos::CoreExt::Colorize
    options :filtered_hosts, :tf_json

    usage "[OPTIONS] -- [COMMANDS] ..."
    parameter "[COMMAND] ...", "Run command on host"

    banner "Opens SSH sessions to hosts in the Kontena Pharos cluster."

    def execute
      if command_list.empty?
        signal_usage_error 'interactive mode can not be used with a non-interactive terminal' unless $stdin.tty? && $stdout.tty?
        run_interactive
        exit 0
      end

      Dir.chdir(config_yaml.dirname) do
        filtered_hosts.each { |host| host.transport.connect }

        exit run_single(filtered_hosts.first) if filtered_hosts.size == 1
        exit run_parallel
      end
    end

    private

    def run_interactive
      filtered_hosts.map do |host|
        target = "#{host.user}@#{host.address}"
        puts "==> Opening a session to #{target} ..".green
        host.transport.interactive_session
      end
    end

    def run_single(host)
      result = host.transport.exec(command_list)
      puts result.output
      result.exit_status
    end

    def run_parallel
      threads = filtered_hosts.map do |host|
        Thread.new do
          [host, host.transport.exec(command_list)]
        rescue StandardError => ex
          [
            host,
            Pharos::Transport::Command::Result.new(host.to_s).tap do |r|
              r.append(ex.message, :stderr)
              r.exit_status = -127
            end
          ]
        end
      end
      results = threads.map(&:value)
      results.each do |host, result|
        puts "==> Result from #{host.user}@#{host.address}".send(result.exit_status.zero? ? :green : :red)
        puts result.output.gsub(/^/, "  ")
      end
      results.all? { |_, result| result.success? } ? 0 : 1
    end
  end
end
