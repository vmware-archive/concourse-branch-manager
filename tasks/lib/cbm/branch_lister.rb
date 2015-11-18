require_relative 'logger'

module Cbm
  # Given a local git repo root, lists the remote branches in alphabetical order
  class BranchLister
    include Logger
    attr_reader :repo_root, :regexp

    def initialize(repo_root, regexp)
      @repo_root = repo_root
      @regexp = Regexp.new(regexp)
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
        branches = filter_branches_based_on_regex(branches)
        branches
      end

      branches.sort
    end

    def reject_head(branches)
      branches.reject { |branch| branch =~ /HEAD/ }
    end

    def strip_remote(branches)
      branches.map { |branch| branch.strip.split('/')[1..-1].join('/') }
    end

    def filter_branches_based_on_regex(branches)
      branches.select { |branch| branch =~ regexp }
    end
  end
end
