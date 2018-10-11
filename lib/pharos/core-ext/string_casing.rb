# frozen_string_literal: true

module Pharos
  module CoreExt
    module StringCasing
      def underscore
        return self if empty?

        result = gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
        result.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
        result.tr!('-', '_')
        result.gsub!(/\s+/, '_')
        result.gsub!(/__+/, '_')
        result.downcase!
        result
      end

      def camelcase
        return self if empty?

        extend(StringCasing).underscore.split('_').map(&:capitalize).join
      end

      def camelback
        return self if empty?

        camelcased = extend(StringCasing).camelcase
        camelcased[0] = camelcased[0].downcase
        camelcased
      end

      %i(underscore camelcase camelback).each do |meth|
        define_method("#{meth}!") do
          return self if empty?

          replace(extend(StringCasing).send(meth))
        end
      end

      refine String do
        include StringCasing
      end

      refine Symbol do
        %i(underscore camelcase camelback).each do |meth|
          define_method(meth) do
            to_s.extend(StringCasing).send(meth)
          end
        end
      end
    end
  end
end
