# frozen_string_literal: true

require 'open3'

module Pharos
  module Terraform
    class BaseCommand < Pharos::Command
      options :yes?

      option "--workspace", "NAME", "terraform workspace", default: "default"

      def tf_workspace
        return 0 if run_cmd("terraform workspace select #{workspace} 2> /dev/null")

        run_cmd("terraform workspace new #{workspace}")
      end

      def workspace_file
        ".#{workspace}.json"
      end

      def run_cmd!(cmd)
        success = run_cmd(cmd)
        signal_error "#{cmd} failed" unless success
      end

      # @param cmd [String]
      # @return [Boolean]
      def run_cmd(cmd)
        system(cmd)
      end
    end
  end
end
