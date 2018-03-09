# frozen_string_literal: true

require 'erb'

module Kupo
  class Erb
    class Namespace
      Error = Class.new(Kupo::Error)

      class NilObject
        def initialize(name)
          @name = name
        end

        def nil?
          true
        end

        def class
          NilClass
        end

        def to_s
          raise NameError, "unknown local variable or method '#{@name}'"
        end
      end

      def initialize(path, hash)
        @path = path
        hash.each do |key, value|
          singleton_class.send(:define_method, key) { value }
        end
      end

      def method_missing(meth, *arg)
        NilObject.new(meth)
      end

      def inspect
        super.sub('>', "for='#{@path}'>")
      end

      def with_binding(&block)
        yield binding
      rescue NameError => ex
        raise Error.new("#{ex.message} in file #{@path}")
      end
    end

    def initialize(path)
      @path = path
    end

    def render(vars = {})
      if erb?
        Namespace.new(@path, vars).with_binding do |ns_binding|
          ERB.new(template, nil, '%<>-').result(ns_binding)
        end
      else
        template
      end
    end

    private

    def erb?
      @path.end_with?('.erb')
    end

    def template
      File.read(@path)
    end
  end
end
