# frozen_string_literal: true

module Pharos
  class YamlFile
    class Namespace
      def initialize(variables)
        variables.each do |key, value|
          singleton_class.send(:define_method, key) { value }
        end
      end

      def with_binding(&block)
        yield binding
      end
    end
  end
end
