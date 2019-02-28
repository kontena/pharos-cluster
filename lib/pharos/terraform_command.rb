# frozen_string_literal: true

require_relative 'terraform/apply_command'
require_relative 'terraform/destroy_command'

module Pharos
  class TerraformCommand < Pharos::Command
    subcommand "apply", "apply terraform configuration", Pharos::Terraform::ApplyCommand
    subcommand "destroy", "destroy terraformed infrastructure", Pharos::Terraform::DestroyCommand
  end
end
