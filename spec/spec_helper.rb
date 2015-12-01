require 'rspec'
require 'tmpdir'
require 'json'
require 'process_helper'
require_relative '../tasks/lib/cbm/logger'

# RSpec config
RSpec.configure do |c|
  c.before(:suite) do
    ENV['GIT_AUTHOR_NAME'] = 'cbm'
    ENV['GIT_AUTHOR_EMAIL'] = 'cbm@example.com'
    ENV['GIT_COMMITTER_NAME'] = 'cbm'
    ENV['GIT_COMMITTER_EMAIL'] = 'cbm@example.com'
  end

  c.before(:each) do
    # squelch log messages during specs
    allow_any_instance_of(Cbm::Logger).to receive(:log)
  end
end

# RSpec helper methods
module SpecHelper
  include ProcessHelper

  def make_git_branches_root
    git_branches_root = Dir.mktmpdir

    git_branches_hash = {
      'uri' => 'https://github.com/user/repo.git',
      'branches' => [
        'master',
        'feature-1'
      ]
    }
    git_branches_json = JSON.dump(git_branches_hash)

    FileUtils.cd(git_branches_root) do
      File.open('git-branches.json', 'w') do |file|
        file.write(git_branches_json)
      end
    end

    git_branches_root
  end
end

include SpecHelper
