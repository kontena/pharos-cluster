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
      def initialize(client, path, expand: false)
        @client = client
        @path = path.dup
        @path.replace(readlink(escape: false, canonicalize: true)) if expand
        @path.freeze

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
      # @param overwrite [Boolean] use force to overwrite target
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def write(content, overwrite: false)
        tmp = temp_file_path.shellescape
        @client.exec!(
          "cat > #{tmp} && (sudo mv #{'-f ' if overwrite}#{tmp} #{escaped_path} || (rm -f #{tmp}; exit 1))",
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

      # True if the file exists. Assumes a bash-like shell.
      # @return [Boolean]
      # @raise [Pharos::ExecError]
      def exist?
        @client.exec!("sudo env -i bash --norc --noprofile -c -- 'test -e #{escaped_path} && echo true || echo false'").strip == "true"
      end

      # Performs the block if the remote file exists, otherwise returns false
      # @yield [Pharos::Transport::TransportFile]
      def with_existing
        exist? && yield(self)
      end

      # Moves the current file to target path
      # @param target [String]
      # @param overwrite [Boolean] use force to overwrite target
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def move(target, overwrite: false)
        @client.exec!("sudo mv #{'-f ' if overwrite}#{@path} #{target.shellescape}")
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

      # @param escape [Boolean] escape file path
      # @param canonicalize [Boolean] canonicalize by following every symlink in every component of the file name recursively; all but the last component must exist
      # @return [String, nil]
      # @raise [Pharos::ExecError]
      def readlink(escape: true, canonicalize: false)
        target = @client.exec!("readlink #{'-f ' if canonicalize}#{escape ? escaped_path : @path} || echo").strip

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

      def temp_file_path(prefix: nil)
        ::File.join('/tmp', "#{prefix || basename}.#{SecureRandom.hex(16)}")
      end

      def escaped_path
        @path.shellescape
      end
    end
  end
end
