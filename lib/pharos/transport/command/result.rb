# frozen_string_literal: true

module Pharos
  module Transport
    module Command
      class Result
        attr_reader :stdin, :stdout, :stderr, :output, :hostname, :exit_status

        def self.mutex
          @mutex ||= Mutex.new
        end

        def initialize(hostname)
          @hostname = hostname
          @stdin = +''
          @stdout = +''
          @stderr = +''
          @output = +''
          @exit_status = -127
          initialize_debug
        end

        def synchronize(&block)
          self.class.mutex.synchronize(&block)
        end

        def exit_status=(exitstatus)
          @exit_status = exitstatus
          debug { debug_exit(exitstatus) }
        end

        def append(data, stream = :stdout)
          case stream
          when :cmd
            debug { debug_cmd(data) }
          when :stdin
            stdin << data
            debug { debug_stdin(data) }
          when :stdout
            stdout << data
            output << data
            debug { debug_stdout(data) }
          when :stderr
            stderr << data
            output << data
            debug { debug_stderr(data) }
          end
        end

        def success?
          exit_status.zero?
        end

        def error?
          !success?
        end

        def initialize_debug
          if !ENV['DEBUG'].to_s.empty?
            @pastel = Pastel.new(enabled: $stdout.tty?)
            @debug_prefix = "    #{@pastel.dim("#{hostname}:")} "
          end
        end

        # @return [Boolean]
        def debug?
          @debug
        end

        if !ENV['DEBUG'].to_s.empty?
          def debug(&block)
            instance_exec(&block)
          end
        else
          def debug(&_block)
            nil
          end
        end

        # @param cmd [String]
        # @return [Integer]
        def debug_cmd(cmd)
          synchronize do
            $stdout << @debug_prefix << @pastel.cyan("$ #{cmd}") << "\n"
          end
        end

        # @param data [String]
        # @return [Integer]
        def debug_stdin(data)
          return if ENV["DEBUG_STDIN"].to_s.empty?
          synchronize do
            $stdout << @debug_prefix << @pastel.green("< #{data}")
          end
        end

        # @param data [String]
        # @return [String]
        def debug_stdout(data)
          synchronize do
            data.each_line do |line|
              $stdout << @debug_prefix << @pastel.dim(line)
              $stdout << "\n" unless line.end_with?("\n")
            end
          end
        end

        # @param data [String]
        # @return [String]
        def debug_stderr(data)
          synchronize do
            data.each_line do |line|
              $stdout << @debug_prefix << @pastel.red(line)
              $stdout << "\n" unless line.end_with?("\n")
            end
          end
        end

        # @param exit_status [Integer]
        # @return [Integer]
        def debug_exit(exit_status)
          synchronize do
            $stdout << @debug_prefix << @pastel.yellow("! #{exit_status}") << "\n"
          end
        end
      end
    end
  end
end
