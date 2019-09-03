# frozen_string_literal: true

module Pharos
  VERSION = "2.4.6"

  def self.version
    VERSION + "+oss"
  end

  def self.oss?
    true
  end
end
