# frozen_string_literal: true

module Pharos
  module Transport
    module Command
      class SSH < Pharos::Transport::Command::Local
        attr_reader :cmd, :result

        def hostname
          @client.host.to_s
        end

        # @return [Pharos::Transport::CommandResult]
        def run
          retried ||= false

          @client.connect unless @client.connected?

          raise Pharos::ExecError.new(@source || cmd, -127, "Connection not established") unless @client.connected?

          result.append(@source.nil? ? @cmd : "#{@cmd} < #{@source}", :cmd)

          response = @client.session.open_channel do |channel|
            channel.env('LC_ALL', 'C.UTF-8')
            channel.exec @cmd do |_, success|
              raise Pharos::ExecError.new(@source || cmd, -127, "Failed to exec #{cmd}") unless success

              channel.on_data do |_, data|
                result.append(data, :stdout)
              end

              channel.on_extended_data do |_c, _type, data|
                result.append(data, :stderr)
              end

              channel.on_request("exit-status") do |_, data|
                result.exit_status = data.read_long
              end

              if @stdin
                result.append(@stdin, :stdin)
                channel.send_data(@stdin)
                channel.eof!
              end
            end
          end

          response.wait

          result
        rescue IOError # Happens on a tunneled connection if the tunnel dies between commands
          raise if retried

          retried = true
          @client.disconnect
          @client.connect
          retry
        end
      end
    end
  end
end
