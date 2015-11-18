require_relative('branch_lister')
require_relative('pipeline_generator')
require_relative('pipeline_updater')
require_relative('logger')

module Cbm
  # Main class and entry point
  class BranchManager
    attr_reader :build_root, :url, :username, :password, :resource_template_file
    attr_reader :job_template_file, :branch_regexp

    def initialize
      @build_root = ENV.fetch('BUILD_ROOT')
      @url = ENV.fetch('CONCOURSE_URL')
      @username = ENV.fetch('CONCOURSE_USERNAME')
      @password = ENV.fetch('CONCOURSE_PASSWORD')
      @resource_template_file = ENV.fetch('BRANCH_RESOURCE_TEMPLATE')
      @job_template_file = ENV.fetch('BRANCH_JOB_TEMPLATE')
      @branch_regexp = ENV.fetch('BRANCH_REGEXP', '.*')
    end

    def run
      managed_repo_root = "#{build_root}/managed-repo"
      branches = Cbm::BranchLister.new(managed_repo_root, branch_regexp).list
      pipeline_file = Cbm::PipelineGenerator.new(
        branches,
        resource_template_file,
        job_template_file).generate
      Cbm::PipelineUpdater.new(url, username, password, pipeline_file).set_pipeline
    end
  end
end
