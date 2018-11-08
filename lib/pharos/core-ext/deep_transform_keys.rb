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
          Hash[value.map { |k, v| [yield(k.frozen? ? k.dup : k), deep_transform_keys(v, &block)] }]
        else
          value
        end
      end

      refine Hash do
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
      end
    end
  end
end
