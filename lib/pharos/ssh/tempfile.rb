# frozen_string_literal: true

require 'securerandom'
require_relative 'remote_file'

module Pharos
  module SSH
    # A temporary filename on a remote host
    # Optionally uploads given content.
    # When used with a block, removes the temporary file after execution.
    class Tempfile < RemoteFile
      # @param client [Pharos::SSH::Client]
      # @param prefix [String] Filename prefix, default "pharos"
      # @param content [NilClass,String,IO] Content to upload to remote host
      # @yield [String] Temporary filename
      # @example
      #   Pharos::SSH::Tempfile.new(client) do |path|
      #     client.exec("uname -a >> #{path}")
      #   end
      # @example
      #   tempfile = Pharos::SSH::Tempfile.new(client)
      #   client.exec("uname -a >> #{path}")
      #   tempfile.unlink
      def initialize(client, prefix: "pharos", content: nil, &block)
        @client = client
        @path = temp_file_path(prefix: prefix)
        @content = content
        freeze
        run(&block) if block_given?
      end

      def write(content)
        @client.exec!(
          "sudo cat > #{@path.shellescape}",
          stdin: content.respond_to?(:read) ? content : StringIO.new(content)
        )
      end

      private

      def run
        write(@content) if @content
        yield @path
      ensure
        begin
          unlink
        rescue Pharos::SSH::RemoteCommand::ExecError
          @client.logger.debug { "File did not exist in ensure" }
        end
      end
    end
  end
end
