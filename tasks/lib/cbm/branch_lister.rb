require_relative 'logger'
require 'json'

module Cbm
  # Given a local git repo root, lists the remote branches in alphabetical order
  class BranchLister
    include Logger
    attr_reader :git_branches_root, :branch_regexp, :max_branches

    def initialize(git_branches_root, branch_regexp, max_branches)
      @git_branches_root = git_branches_root
      @branch_regexp = Regexp.new(branch_regexp)
      @max_branches = max_branches
    end

    def list
      log 'Reading git branches...'
      version_json_text = File.read("#{git_branches_root}/git-branches.json")
      version = JSON.parse(version_json_text)
      branches = version.fetch('branches')
      branches = select_matching(branches)
      branches

      validate_branches(branches)

      branches.sort
    end

    private

    def validate_branches(branches)
      fail(
        "#{branches.size} branches found. Increase MAX_BRANCHES, " \
        'or provide a more specific regular expression.'
      ) if branches.size > max_branches
    end

    def select_matching(branches)
      branches.select { |branch| branch =~ branch_regexp }
    end
  end
end
