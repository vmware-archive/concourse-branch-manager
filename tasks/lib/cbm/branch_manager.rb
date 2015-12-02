require_relative('git_branches_parser')
require_relative('pipeline_generator')
require_relative('pipeline_updater')
require_relative('logger')
require 'json'

module Cbm
  # Main class and entry point
  class BranchManager
    attr_reader :build_root, :url, :username, :password, :resource_template_file
    attr_reader :job_template_file, :load_vars_from_entries, :pipeline_name

    def initialize
      @build_root = ENV.fetch('BUILD_ROOT')
      @url = ENV.fetch('CONCOURSE_URL')
      @username = ENV.fetch('CONCOURSE_USERNAME')
      @password = ENV.fetch('CONCOURSE_PASSWORD')
      @resource_template_file = ENV.fetch('BRANCH_RESOURCE_TEMPLATE')
      @job_template_file = ENV.fetch('BRANCH_JOB_TEMPLATE')
      @pipeline_name = ENV.fetch('PIPELINE_NAME', nil)
      @load_vars_from_entries = parse_load_vars_from_entries
    end

    def run
      git_branches_root = "#{build_root}/git-branches"

      git_uri, branches = Cbm::GitBranchesParser.new(git_branches_root).parse

      pipeline_file = Cbm::PipelineGenerator.new(
        git_uri,
        branches,
        resource_template_file,
        job_template_file).generate
      Cbm::PipelineUpdater.new(
        url,
        username,
        password,
        pipeline_file,
        load_vars_from_entries,
        pipeline_name_or_default(git_uri)).set_pipeline
    end

    private

    def pipeline_name_or_default(git_uri)
      repo = git_uri.split('/').last.gsub('.git', '')
      pipeline_name || "cbm-#{repo}"
    end

    def parse_load_vars_from_entries
      entries = ENV.keys.map do |key|
        regexp = /^(PIPELINE_LOAD_VARS_FROM_\d+)$/
        matches = regexp.match(key)
        ENV.fetch(matches[1]) if matches
      end
      entries.compact
    end
  end
end
