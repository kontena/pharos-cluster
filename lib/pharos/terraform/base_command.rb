# frozen_string_literal: true

require 'open3'

module Pharos::Terraform
  class BaseCommand < Pharos::Command
    options :yes?

    option "--workspace", "NAME", "terraform workspace", default: "default"

    def tf_workspace
      unless run_cmd("terraform workspace select #{workspace} 2> /dev/null").zero?
        run_cmd("terraform workspace new #{workspace}")
      end
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
      $?.exitstatus
    end
  end
end
