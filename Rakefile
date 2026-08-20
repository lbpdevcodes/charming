# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :standard do
  sh "bin/lint"
end

desc "List Charming's public constants (everything outside Charming::Internal) " \
      "so API drift is reviewable. Locked by spec/api_policy_spec.rb."
task "api:public" do
  sh 'bundle exec ruby -Ilib -e \'require "charming"; Zeitwerk::Loader.eager_load_all; ' \
     "def walk(mod, prefix = [], &block); mod.constants(false).sort.each do |name|; " \
     "path = prefix + [name]; yield path, mod.const_get(name); " \
     "walk(mod.const_get(name), path, &block) if mod.const_get(name).is_a?(Module) && path.length < 4; end; end; " \
     'walk(Charming) { |path, const| puts path.join("::") if const.is_a?(Module) && path.first != :Internal }\''
end

task default: %i[spec standard]
