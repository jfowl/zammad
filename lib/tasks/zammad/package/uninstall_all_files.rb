# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require_dependency 'tasks/zammad/command.rb'

module Tasks
  module Zammad
    module Package
      class UninstallAllFiles < Tasks::Zammad::Command
        def self.description
          'Uninstalls all package files in the filesystem only'
        end

        def self.task_handler
          ::Package.all.pluck(:name, :version).each do |name, version|
            puts "Removing files of Package '#{name}'..."

            ::Package.uninstall(
              name:               name,
              version:            version,
              migration_not_down: true,
              reinstall:          true,
            )
          end
        end
      end
    end
  end
end
