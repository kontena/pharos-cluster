# frozen_string_literal: true

module Pharos
  module CoreExt
    module DeepTransformKeys
      using Pharos::CoreExt::StringCasing

      def self.deep_transform_keys(value = nil, &block)
        case value
        when Array
          value.map { |v| deep_transform_keys(v, &block) }
        when Hash
          value.transform_keys do |key|
            if key.is_a?(String) || key.is_a?(Symbol)
              block.call(key.to_s.dup.extend(StringCasing))
            else
              key
            end
          end.transform_values do |inner_value|
            deep_transform_keys(inner_value, &block)
          end
        else
          value
        end
      end

      def deep_transform_keys(&block)
        ::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &block)
      end

      def deep_transform_keys!(&block)
        replace(::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &block))
      end

      def deep_stringify_keys
        ::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &:to_s)
      end

      def deep_stringify_keys!
        replace(::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &:to_s))
      end

      def deep_symbolize_keys
        ::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &:to_sym)
      end

      def deep_symbolize_keys!
        replace(::Pharos::CoreExt::DeepTransformKeys.deep_transform_keys(self, &:to_sym))
      end

      refine Hash do
        include ::Pharos::CoreExt::DeepTransformKeys
      end
    end
  end
end
