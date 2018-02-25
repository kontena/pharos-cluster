module Shokunin
  class Command < Clamp::Command
    def pastel
      @pastel ||= Pastel.new
    end
  end
end
