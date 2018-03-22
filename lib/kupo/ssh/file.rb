# frozen_string_literal: true

require 'shellwords'
require 'securerandom'

module Kupo
  module SSH
    class File
      def initialize(client, path)
        @client = client
        @path = path
      end

      def unlink
        @client.exec!("rm #{escaped_path}")
      end

      def write(content)
        @client.upload(
          content.respond_to?(:read) ? content : StringIO.new(content),
          temp_path
        )
        @client.exec!("sudo mv #{temp_path} #{escaped_path}")
      rescue
        exec("rm #{temp_path}")
        raise
      end

      def read
        @client.exec!("sudo cat #{escaped_path}")
      end

      def exist?
        @client.exec?("[ -e #{escaped_path} ]")
      end

      def download(local_path)
        @session.download(@path, local_path)
      end

      def move(target)
        @client.exec!("sudo mv #{escaped_path} #{Shellwords.escape(target)}")
      end
      alias mv move

      def each_line
        read.split(/[\r\n]/).each do |row|
          yield row
        end
      end

      private

      def escaped_path
        @escaped_path ||= Shellwords.escape(@path)
      end

      def temp_path
        @temp_path ||= File.join('/tmp', "kupo.#{File.basename(@path)}-#{SecureRandom.hex(16)}")
      end
    end
  end
end

