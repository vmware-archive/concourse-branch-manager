require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/logger'
require_relative '../tasks/lib/cbm/pipeline_generator'
require 'yaml'

describe Cbm::PipelineGenerator do
  attr_reader :uri, :branches, :resource_template_fixture, :expected_pipeline_yml_hash

  before do
    @uri = 'https://github.com/user/repo.git'
    @branches = %w(branch1 master)
    @resource_template_fixture = File.expand_path(
      '../../examples/templates/my-repo-branch-resource-template.yml.erb', __FILE__
    )

    @expected_pipeline_yml_hash = {
      'groups' => [
        {
          'name' => '000-all',
          'jobs' => [
            'my-repo-branch-job-branch1',
            'my-repo-branch-job-master',
          ],
        },
        {
          'name' => 'branch1',
          'jobs' => [
            'my-repo-branch-job-branch1',
          ],
        },
        {
          'name' => 'master',
          'jobs' => [
            'my-repo-branch-job-master',
          ],
        },
      ],
      'resources' => [
        {
          'name' => 'my-repo-branch-branch1',
          'type' => 'git',
          'source' => {
            'uri' => 'https://github.com/user/repo.git',
            'branch' => 'branch1',
          },
        },
        {
          'name' => 'my-repo-branch-master',
          'type' => 'git',
          'source' => {
            'uri' => 'https://github.com/user/repo.git',
            'branch' => 'master',
          },
        },
        {
          'name' => 'my-repo-common-resource-master',
          'type' => 'git',
          'source' => {
            'uri' => 'https://github.com/user/repo.git',
            'branch' => 'master',
          },
        },
      ],
      'jobs' => [
        {
          'name' => 'my-repo-branch-job-branch1',
          'plan' => [
            {
              'get' => 'my-repo-branch',
              'resource' => 'my-repo-branch-branch1',
              'params' => { 'depth' => 20 },
              'trigger' => true,
            },
            {
              'get' => 'my-repo-common-resource',
              'resource' => 'my-repo-common-resource-master',
              'params' => { 'depth' => 20 },
              'trigger' => true,
            },
            {
              'task' => 'my-repo-branch-task',
              'file' => 'my-repo-branch/examples/tasks/my-repo-branch-task.yml',
              'config' => {
                'params' => {
                  'BRANCH_NAME' => 'branch1',
                  'EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY' =>
                    '{{EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY}}',
                  'EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY' =>
                    '{{EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY}}',
                },
              },
            },
          ],
        },
        {
          'name' => 'my-repo-branch-job-master',
          'plan' => [
            {
              'get' => 'my-repo-branch',
              'resource' => 'my-repo-branch-master',
              'params' => { 'depth' => 20 },
              'trigger' => true,
            },
            {
              'get' => 'my-repo-common-resource',
              'resource' => 'my-repo-common-resource-master',
              'params' => { 'depth' => 20 },
              'trigger' => true,
            },
            {
              'task' => 'my-repo-branch-task',
              'file' => 'my-repo-branch/examples/tasks/my-repo-branch-task.yml',
              'config' => {
                'params' => {
                  'BRANCH_NAME' => 'master',
                  'EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY' =>
                    '{{EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY}}',
                  'EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY' =>
                    '{{EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY}}',
                },
              },
            }
          ],
        },
      ]
    }
  end

  it 'generates pipeline yml' do
    common_resource_fixture = File.expand_path(
      '../../examples/templates/my-repo-common-resources-template.yml.erb', __FILE__
    )

    job_template_fixture = File.expand_path(
      '../../examples/templates/my-repo-branch-job-template.yml.erb', __FILE__
    )
    subject = Cbm::PipelineGenerator.new(
      uri, branches, resource_template_fixture, job_template_fixture, common_resource_fixture, true
    )

    pipeline_file = subject.generate
    perform_assertion(expected_pipeline_yml_hash, pipeline_file)
  end

  it 'generates pipeline yml without optional common resources template specified' do
    expected_pipeline_yml_hash['resources'].delete_at(2)
    expected_pipeline_yml_hash['jobs'][0]['plan'].delete_at(1)
    expected_pipeline_yml_hash['jobs'][1]['plan'].delete_at(1)

    job_template_fixture = File.expand_path(
      '../fixtures/my-repo-branch-job-template-without-common-resource.yml.erb', __FILE__
    )
    subject = Cbm::PipelineGenerator.new(
      uri, branches, resource_template_fixture, job_template_fixture, nil, true
    )

    pipeline_file = subject.generate
    perform_assertion(expected_pipeline_yml_hash, pipeline_file)
  end

  it 'generates pipeline yml with group_per_branch set to false' do
    expected_pipeline_yml_hash.delete('groups')

    common_resource_fixture = File.expand_path(
      '../../examples/templates/my-repo-common-resources-template.yml.erb', __FILE__
    )

    job_template_fixture = File.expand_path(
      '../../examples/templates/my-repo-branch-job-template.yml.erb', __FILE__
    )
    subject = Cbm::PipelineGenerator.new(
      uri,
      branches,
      resource_template_fixture,
      job_template_fixture,
      common_resource_fixture,
      false
    )

    pipeline_file = subject.generate
    perform_assertion(expected_pipeline_yml_hash, pipeline_file)
  end

  def perform_assertion(expected_pipeline_yml_hash, pipeline_file)
    pipeline_yml = File.read(pipeline_file)

    # convert concourse pipeline param delimiters to strings so we can compare
    # as a hash for this test
    pipeline_yml.gsub!(
      '{{EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY}}',
      '"{{EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY}}"')
    pipeline_yml.gsub!(
      '{{EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY}}',
      '"{{EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY}}"')

    pipeline_yml_hash = YAML.load(pipeline_yml)

    expect(pipeline_yml_hash).to eq(expected_pipeline_yml_hash)
  end
end
