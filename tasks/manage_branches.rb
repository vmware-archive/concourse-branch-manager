#!/usr/bin/env ruby

require_relative 'core/core_setup'
require_relative 'lib/cbm/branch_manager'

puts 'Running BranchManager...'
Cbm::BranchManager.new.run
