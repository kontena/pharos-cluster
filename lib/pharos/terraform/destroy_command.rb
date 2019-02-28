# frozen_string_literal: true

require_relative 'base_command'

module Pharos
  module Terraform
    class DestroyCommand < BaseCommand
      def execute
        tf_workspace
        tf_destroy
      end

      def tf_destroy
        cmd = ["terraform", "destroy"]
        cmd << "-auto-approve" if yes?

        run_cmd!(cmd.join(' '))
        unless workspace == 'default'
          run_cmd! "terraform workspace select default"
          run_cmd! "terraform workspace delete #{workspace}"
        end
        File.delete(workspace_file) if File.exist?(workspace_file)
      end
    end
  end
end
