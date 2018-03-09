# frozen_string_literal: true

module Kupo
  class YamlFile
    class Namespace
      Error = Class.new(Kupo::Error)

      def initialize(path, variables)
        @path = path
        variables.each do |key, value|
          singleton_class.send(:define_method, key) { value }
        end
      end

      def inspect
        super.sub('>', "for='#{@path}'>")
      end

      def with_binding(&block)
        yield binding
      rescue NameError => ex
        raise Error, "#{ex.message} in file #{@path}"
      end
    end
  end
end
