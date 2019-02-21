# frozen_string_literal: true

require_relative 'base_command'

module Pharos
  module Terraform
    class ApplyCommand < BaseCommand
      options :load_config
      option "--var", "VAR", "set a variable in the terraform configuration.", multivalued: true
      option "--var-file", "FILE", 'set variables in the terraform configuration from a file (default: terraform.tfvars or any .auto.tfvars)'
      option ['-f', '--force'], :flag, "force upgrade"

      def execute
        tf_workspace
        tf_init
        tf_apply
        pharos_up
      end

      def tf_init
        run_cmd! "terraform init"
      end

      def tf_apply
        cmd = ["terraform", "apply"]
        cmd << "-auto-approve" if yes?
        cmd << "-var-file #{var_file}" if var_file
        cmd += var_list.map { |var| "-var #{var}" } if var_list

        run_cmd! cmd.join(' ')
      end

      def pharos_up
        run_cmd "terraform output -json > .#{workspace}.json"

        cmd = @config_options || []
        cmd << '--tf-json'
        cmd << ".#{workspace}.json"
        cmd << '-y' if yes?
        cmd << '--force' if force?

        Pharos::UpCommand.new('pharos').run(cmd)
      end
    end
  end
end
