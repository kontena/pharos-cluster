# frozen_string_literal: true

module Pharos
  class Error < StandardError; end
  class InvalidHostError < Error; end
  class InvalidAddonError < Error; end
end
