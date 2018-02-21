module Kuntena
  class UpCommand < Clamp::Command

    option ['-c', '--config'], 'PATH', 'Path to config file', default: 'cluster.yml'


    def execute
      begin
        config_file = File.realpath(config)
      rescue Errno::ENOENT
        signal_usage_error 'File does not exist'
      end

      config = YAML.load(File.read(config_file))
      master_hosts = master_hosts(config)
      signal_usage_error 'No master hosts defined' if master_hosts.size == 0
      signal_usage_error 'Only one host can be in master role' if master_hosts.size > 1

      handle_masters(master_hosts[0])
      handle_workers(master_hosts[0], worker_hosts(config))
    end


    def master_hosts(config)
      config['hosts'].select { |h| h['roles'].include?('master') }
    end

    def worker_hosts(config)
      config['hosts'].select { |h| h['roles'].include?('worker') }
    end

    def handle_masters(master)
      client = Kuntena::SSH::Client.new(master['address'], master['user'] || 'ubuntu')
      client.connect

      puts "==> [#{master['address']}] Installing required packages"
      Kuntena::Services::ConfigureHost.new(client).call

      puts "==> [#{master['address']}] Configuring control plane"
      Kuntena::Services::ConfigureMaster.new(client, host: master['address']).call

      puts "==> [#{master['address']}] Configuring overlay network"
      Kuntena::Services::ConfigureNetwork.new(client, host: master['address']).call

      puts "==> [#{master['address']}] Importing kubectl config"
      Kuntena::Services::ConfigureClient.new(client, host: master['address']).call
    end

    def handle_workers(master, nodes)
      master_client = Kuntena::SSH::Client.new(master['address'], master['user'] || 'ubuntu')
      master_client.connect

      nodes.each do |node|
        begin
          client = Kuntena::SSH::Client.new(node['address'], node['user'] || 'ubuntu')
          client.connect

          puts "==> [#{node['address']}] Installing required packages"
          Kuntena::Services::ConfigureHost.new(client).call

          joiner = Kuntena::Services::JoinNode.new(client)
          unless joiner.already_joined?
            puts "==> [#{node['address']}] Joining to master"
            joiner.join(master_client)
          end
        ensure
          client.disconnect
        end
      end
    ensure
      master_client.disconnect if master_client
    end
  end
end
