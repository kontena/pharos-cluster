# frozen_string_literal: true

require 'securerandom'
require_relative 'transport_file'

module Pharos
  module Transport
    # A temporary filename on a host
    # Optionally uploads given content.
    # When used with a block, removes the temporary file after execution.
    class Tempfile < Pharos::Transport::TransportFile
      # @param client [Pharos::Transport::SSH,Pharos::Transport::Local]
      # @param prefix [String] Filename prefix, default "pharos"
      # @param content [NilClass,String,IO] Content to upload to remote host
      # @yield [String] Temporary filename
      # @example
      #   Pharos::Transport::Tempfile.new(client) do |path|
      #     client.exec("uname -a >> #{path}")
      #   end
      # @example
      #   tempfile = Pharos::Transport::Tempfile.new(client)
      #   client.exec("uname -a >> #{path}")
      #   tempfile.unlink
      def initialize(client, prefix: "pharos", content: nil, &block)
        @client = client
        @path = temp_file_path(prefix: prefix)
        @content = content
        freeze
        run(&block) if block_given?
      end

      # @param content [String]
      # @return [Pharos::Transport::Command::Result]
      # @raise [Pharos::ExecError]
      def write(content)
        @client.exec!(
          "cat > #{escaped_path}",
          stdin: content
        )
      end

      private

      def run
        write(@content) if @content
        yield @path
      ensure
        begin
          unlink
        rescue Pharos::ExecError
          @client.logger.debug { "File did not exist in ensure" }
        end
      end
    end
  end
end
