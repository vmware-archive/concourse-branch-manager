require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/git_branches_parser'
require_relative '../tasks/lib/cbm/branch_manager'
require_relative '../tasks/lib/cbm/pipeline_generator'

describe Cbm::BranchManager do
  it 'has no syntax errors in #run' do
    allow(ENV).to receive(:fetch).and_call_original

    expect(ENV).to receive(:fetch).with('BUILD_ROOT').and_return('/build-root')
    expect(ENV).to receive(:fetch).with('CONCOURSE_URL').and_return('url')
    expect(ENV).to receive(:fetch).with('CONCOURSE_USERNAME').and_return('username')
    expect(ENV).to receive(:fetch).with('CONCOURSE_PASSWORD').and_return('password')
    expect(ENV).to receive(:fetch).with('BRANCH_RESOURCE_TEMPLATE')
        .and_return('template-repo/resource.yml.erb')
    expect(ENV).to receive(:fetch).with('BRANCH_JOB_TEMPLATE')
        .and_return('template-repo/job.yml.erb')
    subject = Cbm::BranchManager.new

    git_branches_parser = double
    expect(Cbm::GitBranchesParser).to receive(:new)
        .with('/build-root/git-branches')
        .and_return(git_branches_parser)
    uri = 'https://github.com/user/repo.git'
    branches = %w(branch1 master)
    expect(git_branches_parser).to receive(:parse).and_return([uri, branches])

    pipeline_generator = double
    expect(Cbm::PipelineGenerator).to receive(:new)
        .with(
          uri,
          branches,
          'template-repo/resource.yml.erb',
          'template-repo/job.yml.erb')
        .and_return(pipeline_generator)
    pipeline_file = double
    expect(pipeline_generator).to receive(:generate).and_return(pipeline_file)

    pipeline_updater = double
    expect(Cbm::PipelineUpdater).to receive(:new)
        .with('url', 'username', 'password', pipeline_file)
        .and_return(pipeline_updater)
    expect(pipeline_updater).to receive(:set_pipeline)

    subject.run
  end
end
