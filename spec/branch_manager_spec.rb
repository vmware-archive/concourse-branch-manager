require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/git_branches_parser'
require_relative '../tasks/lib/cbm/branch_manager'
require_relative '../tasks/lib/cbm/pipeline_generator'

describe Cbm::BranchManager do
  attr_reader :uri, :pipeline_file, :pipeline_updater

  before do
    allow(ENV).to receive(:fetch).and_call_original

    expect(ENV).to receive(:fetch).with('BUILD_ROOT').and_return('/build-root')
    @uri = 'git@github.com:user/repo.git'
    expect(ENV).to receive(:fetch).with('CONCOURSE_URL').and_return(uri)
    expect(ENV).to receive(:fetch).with('CONCOURSE_USERNAME').and_return('username')
    expect(ENV).to receive(:fetch).with('CONCOURSE_PASSWORD').and_return('password')
    expect(ENV).to receive(:fetch).with('BRANCH_RESOURCE_TEMPLATE')
      .and_return('template-repo/resource.yml.erb')
    expect(ENV).to receive(:fetch).with('BRANCH_JOB_TEMPLATE')
      .and_return('template-repo/job.yml.erb')

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
    @pipeline_file = double
    expect(pipeline_generator).to receive(:generate).and_return(pipeline_file)

    @pipeline_updater = double
    expect(pipeline_updater).to receive(:set_pipeline)
  end

  it 'has no syntax errors in #run' do
    expect(ENV).to receive(:keys).and_return(%w(UNRELATED IRRELEVANT))
    subject = Cbm::BranchManager.new
    expect(Cbm::PipelineUpdater).to receive(:new)
      .with(uri, 'username', 'password', pipeline_file, [], 'cbm-repo')
      .and_return(pipeline_updater)
    subject.run
  end

  it 'handles PIPELINE_LOAD_VARS_FROM_n' do
    expect(ENV).to receive(:keys)
      .and_return(%w(PIPELINE_LOAD_VARS_FROM_1 PIPELINE_LOAD_VARS_FROM_2 ZED))
    expect(ENV).to receive(:fetch).with('PIPELINE_LOAD_VARS_FROM_1')
      .and_return('path/to/config')
    expect(ENV).to receive(:fetch).with('PIPELINE_LOAD_VARS_FROM_2')
      .and_return('path/to/credentials')
    subject = Cbm::BranchManager.new
    expected_load_vars_from_entries = [
      'path/to/config',
      'path/to/credentials',
    ]
    expect(Cbm::PipelineUpdater).to receive(:new)
      .with(
        uri,
        'username',
        'password',
        pipeline_file,
        expected_load_vars_from_entries,
        'cbm-repo')
      .and_return(pipeline_updater)
    subject.run
  end

  it 'allows optional override3 of PIPELINE_NAME' do
    expect(ENV).to receive(:keys).and_return(%w(UNRELATED IRRELEVANT))
    expect(ENV).to receive(:fetch).with('PIPELINE_NAME', nil).and_return('name')
    subject = Cbm::BranchManager.new
    expect(Cbm::PipelineUpdater).to receive(:new)
      .with(uri, 'username', 'password', pipeline_file, [], 'name')
      .and_return(pipeline_updater)
    subject.run
  end
end
