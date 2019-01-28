# frozen_string_literal: true

module Pharos
  module CoreExt
    module DeepKeys
      refine Hash do
        def deep_keys(base = nil)
          keys.flat_map do |k|
            flat_key = [base, k].compact.join('.')
            value = self[k]
            case value
            when Hash
              value.deep_keys(flat_key)
            when Array
              if value.all? { |item| item.is_a?(Hash) }
                value.flat_map.with_index { |item, index| item.deep_keys("#{flat_key}.#{index}") }
              else
                flat_key
              end
            else
              flat_key
            end
          end
        end

        def deep_get(key)
          key.to_s.split('.').inject(self) do |memo, part|
            case memo
            when NilClass
              nil
            when Array
              if part.match?(/^\d+$/)
                memo[part.to_i]
              end
            when Hash
              if memo.key?(part.to_s)
                memo[part.to_s]
              elsif memo.key?(part.to_sym)
                memo[part.to_sym]
              end
            else
              memo
            end
          end
        end
      end
    end
  end
end
