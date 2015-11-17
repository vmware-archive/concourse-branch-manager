require 'rspec'
require 'tmpdir'
require 'process_helper'

# RSpec config
RSpec.configure do |c|
  c.before(:suite) do
    ENV['GIT_AUTHOR_NAME'] = 'cbm'
    ENV['GIT_AUTHOR_EMAIL'] = 'cbm@example.com'
    ENV['GIT_COMMITTER_NAME'] = 'cbm'
    ENV['GIT_COMMITTER_EMAIL'] = 'cbm@example.com'
  end
end

# RSpec helper methods
module SpecHelper
  include ProcessHelper

  def make_cloned_repo(options = {})
    commits = options[:commits]
    local_repo_parent_dir = Dir.mktmpdir
    remote_repo_dir = make_remote_repo(commits)

    FileUtils.cd(local_repo_parent_dir) do
      process("git clone #{remote_repo_dir} local_repo", out: :error)
    end
    local_repo_dir = "#{local_repo_parent_dir}/local_repo"

    {
      local: local_repo_dir,
      remote: remote_repo_dir,
    }
  end

  def make_remote_repo(commits = nil)
    unless commits == []
      commits = [
        {
          a: 1,
        }
      ]
    end
    remote_repo_dir = Dir.mktmpdir('remote_repo_')
    FileUtils.cd(remote_repo_dir) do
      process('git init', out: :error)
      commits.each do |commit|
        commit.each do |filename, contents|
          process("echo #{contents} > #{filename}", out: :error)
        end
      end
      process('git add . && git commit -m "commit 1"', out: :error) unless commits.empty?
    end
    remote_repo_dir
  end
end

include SpecHelper
