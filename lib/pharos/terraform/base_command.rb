# frozen_string_literal: true

require 'open3'
require 'English'

module Pharos
  module Terraform
    class BaseCommand < Pharos::Command
      options :yes?

      option "--workspace", "NAME", "terraform workspace", default: "default"

      def tf_workspace
        return 0 if run_cmd("terraform workspace select #{workspace} 2> /dev/null").zero?

        run_cmd("terraform workspace new #{workspace}")
      end

      def workspace_file
        ".#{workspace}.json"
      end

      def run_cmd!(cmd)
        code = run_cmd(cmd)
        signal_error "#{cmd} failed" unless code.zero?
      end

      # @param cmd [String]
      # @return [Integer]
      def run_cmd(cmd)
        system(cmd)
        $CHILD_STATUS.exitstatus
      end
    end
  end
end
