# frozen_string_literal: true

require 'open3'

module Pharos
  module Terraform
    class BaseCommand < Pharos::Command
      options :yes?

      option "--workspace", "NAME", "terraform workspace", default: "default"
      option "--var", "VAR", "set a variable in the terraform configuration.", multivalued: true
      option "--var-file", "FILE", 'set variables in the terraform configuration from a file (default: terraform.tfvars or any .auto.tfvars)'
      option "--state", "PATH", "Path to the state file. Defaults to 'terraform.tfstate'."

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

      # Returns common options for both apply and destroy commands.
      # @return [Array<String>]
      def common_tf_options
        opts = []
        opts << "-auto-approve" if yes?
        opts << "-state #{state}" if state
        opts << "-var-file #{var_file}" if var_file
        opts += var_list.map { |var| "-var #{var}" } if var_list

        opts
      end
    end
  end
end
