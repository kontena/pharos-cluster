# frozen_string_literal: true

Pharos::ClusterManager.phase_dirs << File.join(__dir__, 'pharos_pro', 'phases')
Pharos::ClusterManager.addon_dirs << File.join(__dir__, 'pharos_pro', 'addons')

Dir.glob(File.join(__dir__, 'pharos_pro', 'commands', '*.rb')).each { |command| require command }