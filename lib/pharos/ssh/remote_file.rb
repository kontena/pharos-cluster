# frozen_string_literal: true

require 'shellwords'
require 'securerandom'

module Pharos
  module SSH
    class RemoteFile
      attr_reader :path
      # Initializes an instance of a remote file
      # @param [Pharos::SSH::Client]
      # @param path [String]
      def initialize(client, path)
        @client = client
        @path = path
        freeze
      end

      alias to_s path

      # Removes the remote file
      def unlink
        @client.exec!("rm #{escaped_path}")
      end
      alias rm unlink

      def basename
        File.basename(@path)
      end

      def dirname
        File.dirname(@path)
      end

      def write(content)
        tmp = temp_file_path.shellescape
        @client.exec!(
          "cat > #{tmp} && (sudo mv #{tmp} #{escaped_path} || (rm #{tmp}; exit 1))",
          stdin: content
        )
      end

      def chmod(mode)
        @client.exec!("sudo chmod #{mode} #{escaped_path}")
      end

      # Returns remote jfile content
      # @return [String]
      def read
        @client.exec!("sudo cat #{escaped_path}")
      end

      # True if the path points to something that exists
      # @return [Boolean]
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
      def writable?
        test?('w')
      end

      # True if the path points to a socket
      def socket?
        test?('S')
      end

      # True if the path points to a symlink
      def symlink?
        test?('L')
      end

      # True if the path points to a named pipe
      def pipe?
        test?('p')
      end

      # True if the path points to something that is readable
      def readable?
        test?('r')
      end

      # True if the path points to something that is executable
      def executable?
        test?('x')
      end

      # True if the path points to a file which is larger than zero bytes
      def non_zero?
        test?('s')
      end

      # Performs the block if the remote file exists, otherwise returns false
      # @yield [Pharos::SSH::RemoteFile]
      def with_existing
        exist? && yield(self)
      end

      # Moves the current file to target path
      # @param target [String]
      def move(target)
        @client.exec!("sudo mv #{@path} #{target.shellescape}")
      end
      alias mv move

      # Copies the current file to target path
      # @param target [String]
      def copy(target)
        @client.exec!("sudo cp #{escaped_path} #{target.shellescape}")
      end
      alias cp copy

      # Creates a symlink at the target path that points to the current file
      # @param target [String]
      def link(target)
        @client.exec!("sudo ln -s #{escaped_path} #{target.shellescape}")
      end

      # Yields each line in the remote file
      # @yield [String]
      def each_line
        read.split(/[\r\n]/).each do |row|
          yield row
        end
      end

      private

      def test?(flag)
        @client.exec?("sudo test -#{flag} #{escaped_path}")
      end

      def temp_file_path(prefix: nil)
        File.join('/tmp', "#{prefix || basename}.#{SecureRandom.hex(16)}")
      end

      def escaped_path
        @path.shellescape
      end
    end
  end
end
