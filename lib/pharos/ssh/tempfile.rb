# frozen_string_literal: true

require 'securerandom'

module Pharos
  module SSH
    # A temporary filename on a remote host
    # Optionally uploads given content.
    # When used with a block, removes the temporary file after execution.
    class Tempfile
      attr_reader :path
      # @param client [Pharos::SSH::Client]
      # @param prefix [String] Filename prefix, default "pharos"
      # @param content [NilClass,String,IO] Content to upload to remote host
      # @param file [NilClass,String] Path to a file to upload to remote host
      # @yield [String] Temporary filename
      # @example
      #   Pharos::SSH::Tempfile.new(client) do |path|
      #     client.exec("uname -a >> #{path}")
      #   end
      # @example
      #   tempfile = Pharos::SSH::Tempfile.new(client)
      #   client.exec("uname -a >> #{path}")
      #   tempfile.unlink
      def initialize(client, prefix: "pharos", content: nil, file: nil, &block)
        @client = client
        @path = File.join('/tmp', "#{prefix}.#{SecureRandom.hex(16)}")
        raise ArgumentError, "Both file and content given" if content && file
        upload_content(content) if content
        upload_file(file) if file
        run(&block) if block_given?
      end

      alias to_s path

      # Upload content to remote tempfile
      # @param content [IO,String]
      # @param opts [Hash] options that are passed to scp.upload!
      # @return [Integer] uploaded bytes
      def upload_content(content, opts = {})
        @client.upload(content.respond_to?(:read) ? content : StringIO.new(content), path, opts)
      end

      # Upload content to remote tempfile
      # @param filename [String]
      # @param opts [Hash] options that are passed to scp.upload!
      # @return [Integer] uploaded bytes
      def upload_file(filename, opts = {})
        @client.upload(filename, path, opts)
      end

      # Tries to automatically detect the passed in object type
      #
      # Objects that respond to .read and strings that contain linefeeds
      # are considered references to IO objects or strings representing
      # uploaded content.
      #
      # Strings without linefeeds are considered paths to local files
      # @param file_or_content [String,IO]
      # @param opts [Hash] options that are passed to scp.upload!
      def upload(file_or_content, opts = {})
        if file_or_content.respond_to?(:read) || file_or_content.include?("\n")
          upload_content(file_or_content, opts)
        else
          upload_file(file_or_content, opts)
        end
      end

      # Remove remote tempfile
      def unlink
        @client.exec("rm #{path}")
      end

      private

      def run
        yield @path
      ensure
        unlink
      end
    end
  end
end
