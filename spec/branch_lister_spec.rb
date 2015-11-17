require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/branch_lister'

describe Cbm::BranchLister do
  it 'lists remote branches alphabetically' do
    local_repo = make_cloned_repo[:local]

    FileUtils.cd(local_repo) do
      process('git checkout -b aaa', out: :error)
      process('git push', out: :error)
      process('git checkout -b zzz', out: :error)
      process('git push', out: :error)
    end

    subject = Cbm::BranchLister.new(local_repo)
    branches = subject.list
    expect(branches).to eq(%w(aaa master zzz))
  end
end
