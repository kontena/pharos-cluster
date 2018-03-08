module Kupo
  class Error < StandardError; end
  class InvalidHostError < Error; end
  class ScriptExecError < Error; end
end