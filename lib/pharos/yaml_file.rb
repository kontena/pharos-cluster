# frozen_string_literal: true

require 'yaml'
require 'erb'
require_relative 'yaml_file/namespace'

module Pharos
  # Reads YAML files and optionally performs ERB evaluation
  class YamlFile
    ParseError = Class.new(StandardError)

    attr_reader :content, :filename

    # @param input [String,IO] A IO/File object, a path to a file or string content
    # @param override_filename [String] use string as the filename for parse errors
    # @param force_erb [Boolean] force erb processing even if filename does not end in .yml or is unknown
    def initialize(input, override_filename: nil, force_erb: false)
      @filename = override_filename
      if input.respond_to?(:read)
        @content = input.read
        @filename ||= input.respond_to?(:path) ? input.path : input.to_s
      else
        @filename ||= input.to_s
        @content = File.read(input)
      end
      @force_erb = force_erb
    end

    def load(variables = {})
      result = YAML.safe_load(read(variables), [], [], true, @filename)
      if result.is_a?(String)
        raise ParseError, "File #{"#{@filename} " if @filename}does not appear to be in YAML format"
      end

      result
    rescue Psych::SyntaxError => ex
      raise ParseError, ex.message
    end

    def dirname
      File.dirname(@filename)
    end

    def basename
      File.basename(@filename)
    end

    def read(variables = {})
      erb? ? erb_result(variables) : @content
    end

    def erb_result(variables = {})
      Namespace.new(variables).with_binding do |ns_binding|
        ERB.new(@content, nil, '%<>-').tap { |e| e.location = [@filename, nil] }.result(ns_binding)
      end
    rescue StandardError, ScriptError => ex
      raise ParseError, "#{ex.class.name} : #{ex.message} (#{ex.backtrace.first.gsub(/:in `with_binding'/, '')})"
    end

    private

    def erb?
      force_erb? || @filename&.end_with?('.erb')
    end

    def force_erb?
      @force_erb
    end
  end
end
