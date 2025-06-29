# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/extensiontask"

task build: :compile

GEMSPEC = Gem::Specification.load("cocoawebview.gemspec")

Rake::ExtensionTask.new("cocoawebview", GEMSPEC) do |ext|
  ext.lib_dir = "lib/cocoawebview"
end

task default: %i[clobber compile]
