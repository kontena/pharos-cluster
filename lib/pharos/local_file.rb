# frozen_string_literal: true

require 'pathname'
require 'fileutils'

module Pharos
  class LocalFile < Pathname
    alias rm unlink
    alias link make_symlink
    alias lines readlines

    # Performs the block if the remote file exists, otherwise returns false
    # @yield [Pharos::SSH::RemoteFile]
    def with_existing
      exist? && yield(self)
    end

    # Moves the current file to target path
    # @param target [String]
    def move(target)
      FileUtils.mv(self, target)
    end
    alias mv move

    # Copies the current file to target path
    # @param target [String]
    # @return [Pharos::SSH::RemoteCommand::Result]
    # @raises [Pharos::SSH::RemoteCommand::ExecError]
    def copy(target)
      FileUtils.cp(self, target)
    end
    alias cp copy
  end
end
