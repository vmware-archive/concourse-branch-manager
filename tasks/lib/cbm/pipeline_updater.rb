require 'process_helper'
require 'tmpdir'
require 'open-uri'

module Cbm
  # Creates/updates pipeline via fly
  class PipelineUpdater
    include Logger
    include ProcessHelper

    attr_reader :url, :username, :password, :pipeline_file, :fly_path

    def initialize(url, username, password, pipeline_file)
      @url = url
      @username = username
      @password = password
      @pipeline_file = pipeline_file
      @fly_path = "#{Dir.mktmpdir}/fly"
    end

    def set_pipeline
      download_fly

      log 'Logging into concourse...'
      process(
        "#{fly_path} --target=concourse login --concourse-url=#{url}",
        timeout: 5,
        input_lines: [username, password])

      log 'Updating pipeline...'
      set_pipeline_cmd = "#{fly_path} --target=concourse set-pipeline --config=#{pipeline_file} " \
        '--pipeline=branch-manager'
      process(set_pipeline_cmd, timeout: 5, input_lines: %w(y))

      log 'Unpausing pipeline...'
      unpause_pipeline_cmd = "#{fly_path} --target=concourse unpause-pipeline " \
        '--pipeline=branch-manager'
      process(unpause_pipeline_cmd, timeout: 5)
    end

    private

    def download_fly
      log 'Downloading fly executable...'

      fly_download_url = "#{url}/api/v1/cli?arch=amd64&platform=linux"
      read_binary_open_mode = 'rb'
      stream = open(
        fly_download_url,
        read_binary_open_mode,
        http_basic_authentication: [username, password])
      IO.copy_stream(stream, fly_path)
      process("chmod +x #{fly_path}")
    end
  end
end
