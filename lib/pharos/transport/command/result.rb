# frozen_string_literal: true

module Pharos
  module Transport
    module Command
      class Result
        using Pharos::CoreExt::Colorize

        attr_reader :stdin, :stdout, :stderr, :output, :hostname, :exit_status

        def self.mutex
          @mutex ||= Mutex.new
        end

        # @param hostname [String]
        def initialize(hostname)
          @hostname = hostname
          @stdin = +''
          @stdout = +''
          @stderr = +''
          @output = +''
          @exit_status = -127
          initialize_debug
        end

        # @param exitstatus [Integer]
        def exit_status=(exitstatus)
          @exit_status = exitstatus
          debug { debug_exit(exitstatus) }
        end

        # Append text to one of the streams
        # @param data [String]
        # @param stream [Symbol]
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

        # @return [Boolean] true when exit status is zero
        def success?
          exit_status.zero?
        end

        # @return [Boolean] true when exit status is non zero
        def error?
          !success?
        end

        # @return [Boolean]
        def debug?
          @debug
        end

        # @param cmd [String]
        # @return [IO] $stdout
        def debug_cmd(cmd)
          synchronize do
            $stdout << @debug_prefix << "$ #{cmd}".cyan << "\n"
          end
        end

        # @param data [String]
        # @return [IO] $stdout
        def debug_stdin(data)
          return if ENV["DEBUG_STDIN"].to_s.empty?

          synchronize do
            $stdout << @debug_prefix << "< #{data}".green
          end
        end

        # @param data [String]
        # @return [IO] $stdout
        def debug_stdout(data)
          synchronize do
            data.each_line do |line|
              $stdout << @debug_prefix << line.dim
              $stdout << "\n" unless line.end_with?("\n")
            end
          end
        end

        # @param data [String]
        # @return [IO] $stdout
        def debug_stderr(data)
          synchronize do
            data.each_line do |line|
              $stdout << @debug_prefix << line.red
              $stdout << "\n" unless line.end_with?("\n")
            end
          end
        end

        # @param exit_status [Integer]
        # @return [IO] $stdout
        def debug_exit(exit_status)
          synchronize do
            $stdout << @debug_prefix << "! #{exit_status}".yellow << "\n"
          end
        end

        private

        def debug(&block)
          Pharos::Logging.debug? ? instance_exec(&block) : nil
        end

        def synchronize(&block)
          self.class.mutex.synchronize(&block)
        end

        def initialize_debug
          return unless Pharos::Logging.debug?

          @debug_prefix = "    #{"#{hostname}:".dim} "
        end
      end
    end
  end
end
