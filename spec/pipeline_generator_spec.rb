require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/pipeline_generator'
require 'yaml'

describe Cbm::PipelineGenerator do
  it 'generates pipeline yml' do
    branches = %w(branch1 master)
    resource_template_fixture = File.expand_path(
      '../../examples/templates/my-repo-branch-resource-template.yml.erb', __FILE__
    )
    job_template_fixture = File.expand_path(
      '../../examples/templates/my-repo-branch-job-template.yml.erb', __FILE__
    )
    subject = Cbm::PipelineGenerator.new(branches, resource_template_fixture, job_template_fixture)

    expected_pipeline_yml_hash = {
      'resources' => [
        {
          'name' => 'my-repo-branch-branch1',
          'type' => 'git',
          'source' => {
            'uri' => 'https://github.com/pivotaltracker/concourse-branch-manager.git',
            'branch' => 'branch1',
          },
        },
        {
          'name' => 'my-repo-branch-master',
          'type' => 'git',
          'source' => {
            'uri' => 'https://github.com/pivotaltracker/concourse-branch-manager.git',
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
              'params' => { 'depth' => 1 },
            },
            {
              'task' => 'my-repo-branch-task',
              'file' => 'my-repo-branch/examples/tasks/my-repo-branch-task.yml',
              'config' => {
                'params' => {
                  'BRANCH_NAME' => 'branch1',
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
              'params' => { 'depth' => 1 },
            },
            {
              'task' => 'my-repo-branch-task',
              'file' => 'my-repo-branch/examples/tasks/my-repo-branch-task.yml',
              'config' => {
                'params' => {
                  'BRANCH_NAME' => 'master',
                },
              },
            }
          ],
        },
      ]
    }

    pipeline_file = subject.generate
    pipeline_yml = File.read(pipeline_file)
    pipeline_yml_hash = YAML.load(pipeline_yml)

    expect(pipeline_yml_hash).to eq(expected_pipeline_yml_hash)
  end
end
