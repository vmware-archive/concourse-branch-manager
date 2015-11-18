require_relative 'logger'

module Cbm
  # Given a local git repo root, lists the remote branches in alphabetical order
  class BranchLister
    include Logger
    attr_reader :repo_root, :branch_regexp, :max_branches

    def initialize(repo_root, branch_regexp, max_branches)
      @repo_root = repo_root
      @branch_regexp = Regexp.new(branch_regexp)
      @max_branches = max_branches
    end

    def list
      branches = []

      FileUtils.cd(repo_root) do
        log 'Listing remote git branches...'
        process('git fetch origin +refs/heads/*:refs/remotes/origin/*', out: :error)
        branch_str = process('git branch -r', out: :error)
        branches = branch_str.split("\n")
        branches = reject_head(branches)
        branches = strip_remote(branches)
        branches = select_matching(branches)
        branches
      end

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

    def reject_head(branches)
      branches.reject { |branch| branch =~ /HEAD/ }
    end

    def strip_remote(branches)
      branches.map { |branch| branch.strip.split('/')[1..-1].join('/') }
    end

    def select_matching(branches)
      branches.select { |branch| branch =~ branch_regexp }
    end
  end
end
