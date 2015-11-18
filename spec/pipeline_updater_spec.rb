require_relative 'spec_helper'
require_relative '../tasks/lib/cbm/pipeline_updater'

describe Cbm::PipelineUpdater do
  it 'updates pipeline' do
    url = 'http://myconcourse.example.com'
    username = 'admin'
    password = 'password'
    pipeline_file = double

    subject = Cbm::PipelineUpdater.new(url, username, password, pipeline_file)
    allow(subject).to receive(:fly_path).and_return('/path/to/fly')

    fly_download_url = 'http://myconcourse.example.com/api/v1/cli?arch=amd64&platform=linux'
    creds = %w(admin password)
    stream = double
    expect(subject).to receive(:open)
        .with(fly_download_url, 'rb', http_basic_authentication: creds)
        .and_return(stream)
    expect(IO).to receive(:copy_stream).with(stream, '/path/to/fly')

    expect(subject).to receive(:process).with('chmod +x /path/to/fly')

    login_cmd = '/path/to/fly --target=concourse login ' \
      '--concourse-url=http://myconcourse.example.com'
    expect(subject).to receive(:process)
        .with(login_cmd, timeout: 5, input_lines: %w(admin password))

    expect(pipeline_file).to receive(:to_s).and_return('/tmp/pipeline.yml')
    set_pipeline_cmd = '/path/to/fly --target=concourse set-pipeline ' \
      '--config=/tmp/pipeline.yml --pipeline=branch-manager'
    expect(subject).to receive(:process).with(set_pipeline_cmd, timeout: 5, input_lines: %w(y))

    unpause_cmd = '/path/to/fly --target=concourse unpause-pipeline --pipeline=branch-manager'
    expect(subject).to receive(:process).with(unpause_cmd, timeout: 5)

    subject.set_pipeline
  end
end
