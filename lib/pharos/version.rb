# frozen_string_literal: true

module Pharos
  VERSION = "2.3.1"

  def self.version
    VERSION + "+oss"
  end

  def self.oss?
    true
  end
end
