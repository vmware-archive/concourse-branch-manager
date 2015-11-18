require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/branch_lister'

describe Cbm::BranchLister do
  it 'lists remote branches alphabetically' do
    cloned_repo = make_cloned_repo
    local_repo = cloned_repo[:local]
    remote_repo = cloned_repo[:remote]

    FileUtils.cd(local_repo) do
      process('git checkout -b aaa', out: :error)
      process('git push', out: :error)
      process('git checkout -b zzz', out: :error)
      process('git push', out: :error)
    end

    FileUtils.cd(remote_repo) do
      process('git checkout -b uncloned', out: :error)
    end

    subject = Cbm::BranchLister.new(local_repo, '.*', 20)
    branches = subject.list
    expect(branches).to eq(%w(aaa master uncloned zzz))
  end

  it 'lists only branches matching the specified regex' do
    local_repo = make_cloned_repo[:local]

    FileUtils.cd(local_repo) do
      process('git checkout -b feature-1', out: :error)
      process('git push', out: :error)
      process('git checkout -b feature-2', out: :error)
      process('git push', out: :error)
      process('git checkout -b zzz', out: :error)
      process('git push', out: :error)
    end

    subject = Cbm::BranchLister.new(local_repo, 'feature-', 20)
    branches = subject.list
    expect(branches).to eq(%w(feature-1 feature-2))
  end

  it 'handles branches containing slashes and regex special characters' do
    local_repo = make_cloned_repo[:local]

    FileUtils.cd(local_repo) do
      process('git checkout -b feat/feature-1', out: :error)
      process('git push', out: :error)
      process('git checkout -b feat{feature-2', out: :error)
      process('git push', out: :error)
      process('git checkout -b zzz', out: :error)
      process('git push', out: :error)
    end

    subject = Cbm::BranchLister.new(local_repo, 'feat(\/|\{)feature-', 20)
    branches = subject.list
    expect(branches).to eq(%w(feat/feature-1 feat{feature-2))
  end

  it 'fails if more than MAX_BRANCHES matches' do
    local_repo = make_cloned_repo[:local]

    FileUtils.cd(local_repo) do
      process('git checkout -b feature-1', out: :error)
      process('git push', out: :error)
      process('git checkout -b feature-2', out: :error)
      process('git push', out: :error)
      process('git checkout -b feature-3', out: :error)
      process('git push', out: :error)
    end

    max_branches = 2
    subject = Cbm::BranchLister.new(local_repo, 'feature-', max_branches)
    expected_msg = '3 branches found. Increase MAX_BRANCHES, ' \
      'or provide a more specific regular expression.'
    expect { subject.list }.to raise_error(RuntimeError, expected_msg)
  end
end
