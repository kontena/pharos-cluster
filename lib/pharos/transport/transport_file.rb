# frozen_string_literal: true

require 'shellwords'
require 'securerandom'

module Pharos
  module Transport
    class TransportFile
      attr_reader :path
      # Initializes an instance of a remote file
      # @param [Pharos::Transport::Base]
      # @param path [String]
      def initialize(client, path)
        @client = client
        @path = path
        freeze
      end

      alias to_s path

      # Removes the remote file
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def unlink
        @client.exec!("sudo rm #{escaped_path}")
      end
      alias rm unlink

      # @return [String]
      def basename
        ::File.basename(@path)
      end

      # @return [String]
      def dirname
        ::File.dirname(@path)
      end

      # @param content [String]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def write(content)
        tmp = temp_file_path.shellescape
        @client.exec!(
          "cat > #{tmp} && (sudo mv #{tmp} #{escaped_path} || (rm #{tmp}; exit 1))",
          stdin: content
        )
      end

      # @param mode [String, Integer]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def chmod(mode)
        @client.exec!("sudo chmod #{mode} #{escaped_path}")
      end

      # Returns remote jfile content
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def read
        @client.exec!("sudo cat #{escaped_path}")
      end

      # True if the path points to something that exists
      # @return [Boolean]
      # @raise [Pharos::ExecError]
      def exist?
        test?('e')
      end

      # True if the path points to a directory
      # @return [Boolean]
      def directory?
        test?('d')
      end

      # True if the path points to a regular file
      # @return [Boolean]
      def file?
        test?('f')
      end

      # True if the path points to a something that is writable
      # @return [Boolean]
      def writable?
        test?('w')
      end

      # True if the path points to a socket
      # @return [Boolean]
      def socket?
        test?('S')
      end

      # True if the path points to a symlink
      # @return [Boolean]
      def symlink?
        test?('L')
      end

      # True if the path points to a named pipe
      # @return [Boolean]
      def pipe?
        test?('p')
      end

      # True if the path points to something that is readable
      # @return [Boolean]
      def readable?
        test?('r')
      end

      # True if the path points to something that is executable
      # @return [Boolean]
      def executable?
        test?('x')
      end

      # True if the path points to a file which is larger than zero bytes
      # @return [Boolean]
      def non_zero?
        test?('s')
      end

      # Performs the block if the remote file exists, otherwise returns false
      # @yield [Pharos::Transport::TransportFile]
      def with_existing
        exist? && yield(self)
      end

      # Moves the current file to target path
      # @param target [String]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def move(target)
        @client.exec!("sudo mv #{@path} #{target.shellescape}")
      end
      alias mv move

      # Copies the current file to target path
      # @param target [String]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def copy(target)
        @client.exec!("sudo cp #{escaped_path} #{target.shellescape}")
      end
      alias cp copy

      # Creates a symlink at the target path that points to the current file
      # @param target [String]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def link(target)
        @client.exec!("sudo ln -s #{escaped_path} #{target.shellescape}")
      end

      # @return [String, nil]
      # @raise [Pharos::ExecError]
      def readlink
        target = @client.exec!("readlink #{escaped_path} || echo").strip

        return nil if target.empty?

        target
      end

      # Returns an array of lines in the remote file
      # @return [Array<String>]
      def lines
        read.lines
      end

      # Yields each line in the remote file
      # @yield [String]
      def each_line(&block)
        read.each_line(&block)
      end

      private

      def test?(flag)
        @client.exec!("sudo env -i bash --norc --noprofile -c -- 'test -#{flag} #{escaped_path} && echo true || echo false'").strip == "true"
      end

      def temp_file_path(prefix: nil)
        ::File.join('/tmp', "#{prefix || basename}.#{SecureRandom.hex(16)}")
      end

      def escaped_path
        @path.shellescape
      end
    end
  end
end
