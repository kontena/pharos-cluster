# frozen_string_literal: true

module Pharos
  # @return [Boolean] true when running the OSS licensed version
  def self.oss?
    false
  end
end

Dir.glob(File.join(__dir__, 'commands/*.rb')).each { |file| require file }
