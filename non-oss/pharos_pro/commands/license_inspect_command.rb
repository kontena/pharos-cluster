# frozen_string_literal: true

module Pharos
  class LicenseInspectCommand < Pharos::Command
    using Pharos::CoreExt::Colorize

    parameter "[LICENSE_KEY]", "kontena pharos license key (default: <stdin>)"
    option %w(-q --quiet), :flag, 'exit with error status when license is not valid'

    def default_license_key
      signal_usage_error 'LICENSE_KEY required' if stdin_eof?

      $stdin.read
    end

    def jwt_token
      @jwt_token ||= Pharos::LicenseKey.new(license_key, cluster_id: nil)
    end

    def execute
      exit 1 if quiet? && !jwt_token.valid?

      puts decorate_license

      signal_error "License is not valid".red unless jwt_token.valid?
    end

    def decorate_license
      lexer = Rouge::Lexers::YAML.new
      if color?
        rouge.format(lexer.lex(jwt_token.to_h.to_yaml.delete_prefix("---\n")))
      else
        jwt_token.to_h.to_yaml.delete_prefix("---\n")
      end
    end
  end
end
