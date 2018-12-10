# frozen_string_literal: true

module Pharos
  class CompleteCommand < Pharos::Command
    SUPPORTED_SHELLS = %w(bash zsh)

    banner "outputs shell auto-completion script. to load, use:\n  source <(#{File.basename($PROGRAM_NAME)} complete)"

    option %w(-s --shell), "[#{SUPPORTED_SHELLS.join('|')}]", "shell to export completions for", environment_variable: 'SHELL', default: 'bash' do |shell|
      shell = File.basename(shell) if shell.include?('/')
      if SUPPORTED_SHELLS.include?(shell)
        shell
      else
        warn "(using 'bash' because #{shell} can not be identified as one of: #{SUPPORTED_SHELLS.join(',')})"
        "bash"
      end
    end

    def execute
      send(shell)
    end

    def bash
      puts Pharos::YamlFile.new(
        File.open(File.join(__dir__, 'completions', 'bash.sh.erb'))
      ).erb_result(tree: tree)
    end
    alias zsh bash

    # Flattens the hash from { command: { subcommand: [] } } to { "command subcommand" => [] }
    # Also doubles the --[no-]-xyz options into separate --xyz and --no-xyz
    #
    # Outcome is something like:
    # { ["pharos-cluster", "license" "assign"] =>
    #   [{:switch=>"--description", :description=>"license description", :param=>"TEXT"},
    #    {:switch=>"--config", :description=>"path to config file (default: cluster.yml)", :param=>"YAML_FILE"},
    #    ...
    #   ]
    # }
    def tree(base = nil, command = [File.basename($PROGRAM_NAME)])
      base ||= subcommand_tree
      result = {}
      case base
      when Hash
        base.each do |cmd, leaf|
          result.merge!(tree(leaf, command + [cmd]))
        end
      when Array
        new_array = []
        base.each do |option|
          if option[:switch].include?('[no-]')
            new_array << option.merge(switch: option[:switch].sub('[no-]', ''))
            new_array << option.merge(switch: option[:switch].sub('[no-]', 'no-'))
          else
            new_array << option
          end
        end
        result[command] = new_array
      else
        result[command] = base
      end
      result
    end

    # Builds a nested hash of subcommands and their options
    def subcommand_tree(base = Pharos::RootCommand)
      if base.has_subcommands?
        base.recognised_subcommands.map do |sc|
          [sc.names.first, subcommand_tree(sc.subcommand_class)]
        end.to_h
      else
        base.recognised_options.map do |opt|
          {
            switch: opt.long_switch,
            description: opt.description,
            param: opt.type == :flag ? nil : opt.type
          }
        end
      end
    end
  end
end
