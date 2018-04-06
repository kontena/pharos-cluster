# frozen_string_literal: true

require 'shellwords'

module Pharos
  module SSH
    class RemoteFile
      def initialize(client, path)
        @client = client
        @path = path.shellescape
        freeze
      end

      def unlink
        @client.exec!("rm #{@path}")
      end

      def write(content)
        @client.exec!(
          "sudo tee #{@path} > /dev/null",
          stdin: content.respond_to?(:read) ? content : StringIO.new(content)
        )
      end

      def read
        @client.exec!("sudo cat #{@path}")
      end

      def exist?
        @client.exec?("[ -e #{@path} ]")
      end

      def with_existing
        exist? && yield(self)
      end

      def download(local_path)
        @session.download(@path, local_path)
      end

      def move(target)
        @client.exec!("sudo mv #{@path} #{target.shellescape}")
      end
      alias mv move

      def copy(target)
        @client.exec!("sudo cp #{@path} #{target.shellescape}")
      end
      alias cp copy

      def link(target)
        @client.exec!("sudo ln -s #{@path} #{target.shellescape}")
      end

      def each_line
        read.split(/[\r\n]/).each do |row|
          yield row
        end
      end
    end
  end
end
