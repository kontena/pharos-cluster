# frozen_string_literal: true

require 'pastel'

module Pharos
  module CoreExt
    module Colorize
      def self.pastel
        @pastel ||= Pastel.new(enabled: true)
      end

      def self.disable!
        @pastel = Pastel.new(enabled: false)
      end

      refine String do
        Pastel::ANSI::ATTRIBUTES.each_key do |meth|
          next if meth == :underscore

          define_method(meth) do
            Pharos::CoreExt::Colorize.pastel.send(meth, self)
          end
        end
      end
    end
  end
end
