# frozen_string_literal: true

module Pharos
  VERSION = "2.4.0-alpha.1"

  def self.version
    VERSION + "+oss"
  end

  def self.oss?
    true
  end
end
