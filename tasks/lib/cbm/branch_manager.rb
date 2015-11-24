require_relative('git_branches_parser')
require_relative('pipeline_generator')
require_relative('pipeline_updater')
require_relative('logger')
require 'json'

module Cbm
  # Main class and entry point
  class BranchManager
    attr_reader :build_root, :url, :username, :password, :resource_template_file
    attr_reader :job_template_file

    def initialize
      @build_root = ENV.fetch('BUILD_ROOT')
      @url = ENV.fetch('CONCOURSE_URL')
      @username = ENV.fetch('CONCOURSE_USERNAME')
      @password = ENV.fetch('CONCOURSE_PASSWORD')
      @resource_template_file = ENV.fetch('BRANCH_RESOURCE_TEMPLATE')
      @job_template_file = ENV.fetch('BRANCH_JOB_TEMPLATE')
    end

    def run
      git_branches_root = "#{build_root}/git-branches"

      uri, branches = Cbm::GitBranchesParser.new(git_branches_root).parse

      pipeline_file = Cbm::PipelineGenerator.new(
        uri,
        branches,
        resource_template_file,
        job_template_file).generate
      Cbm::PipelineUpdater.new(url, username, password, pipeline_file).set_pipeline
    end
  end
end
