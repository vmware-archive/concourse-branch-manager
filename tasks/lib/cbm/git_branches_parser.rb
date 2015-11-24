require_relative 'logger'
require 'json'

module Cbm
  # Given a local git branches resource root containing git-branches.json,
  # parses it and returns the repo uri and array of branches it contains
  class GitBranchesParser
    include Logger
    attr_reader :git_branches_root

    def initialize(git_branches_root)
      @git_branches_root = git_branches_root
    end

    def parse
      log 'Reading uri and git branches...'
      git_branches_json = File.read("#{git_branches_root}/git-branches.json")
      git_branches_hash = JSON.parse(git_branches_json)
      branches = git_branches_hash.fetch('branches').sort
      uri = git_branches_hash.fetch('uri')

      [uri, branches]
    end
  end
end
