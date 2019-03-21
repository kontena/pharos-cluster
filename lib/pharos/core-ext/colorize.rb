# frozen_string_literal: true

module Pharos
  module CoreExt
    module Colorize
      ATTRIBUTES = %i(
        clear reset bold dark dim italic underline inverse hidden
        strikethrough black red green yellow blue magenta cyan white on_black
        on_red on_green on_yellow on_blue on_magenta on_cyan on_white bright_black
        bright_red bright_green bright_yellow bright_blue bright_magenta bright_cyan
        bright_white on_bright_black on_bright_red on_bright_green on_bright_yellow
        on_bright_blue on_bright_magenta on_bright_cyan on_bright_white
      ).freeze

      def self.pastel
        @pastel ||= Pastel.new(enabled: true)
      end

      def self.disable!
        @pastel = Pastel.new(enabled: false)
      end

      def self.enabled?
        pastel.enabled?
      end

      refine String do
        ATTRIBUTES.each do |meth|
          define_method(meth) do
            Pharos::CoreExt::Colorize.pastel.send(meth, self)
          end
        end
      end
    end
  end
end
