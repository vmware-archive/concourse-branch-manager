require_relative 'logger'

module Cbm
  # Given a local git repo root, lists the remote branches in alphabetical order
  class BranchLister
    include Logger
    attr_reader :repo_root

    def initialize(repo_root)
      @repo_root = repo_root
    end

    def list
      branches = []

      FileUtils.cd(repo_root) do
        log 'Listing remote git branches...'
        branch_str = process('git branch -r', out: :error)

        branches = branch_str.split("\n")
          .reject { |branch| branch =~ /HEAD/ }
          .map { |branch| branch.strip.split('/')[1] }
      end

      branches.sort
    end
  end
end
