require 'yaml'
require 'tmpdir'
require 'erb'

module Cbm
  # Generates pipeline yml based on branches
  class PipelineGenerator
    include Logger
    attr_reader :git_uri, :branches, :resource_template_file, :job_template_file
    attr_reader :common_resource_template_file, :group_per_branch, :resource_type_template_file

    # TODO: do http://www.refactoring.com/catalog/introduceParameterObject.html
    # rubocop:disable Metrics/LineLength, Metrics/ParameterLists
    def initialize(git_uri, branches, resource_template_file, job_template_file, common_resource_template_file, resource_type_template_file, group_per_branch)
      @git_uri = git_uri
      @branches = branches
      @resource_template_file = resource_template_file
      @job_template_file = job_template_file
      @common_resource_template_file = common_resource_template_file
      @resource_type_template_file = resource_type_template_file
      @group_per_branch = group_per_branch
    end

    def generate
      log 'Generating pipeline file...'

      pipeline_yml = build_yml

      log 'Generated pipeline yml:'
      log '-' * 80
      log pipeline_yml
      log '-' * 80

      write_pipeline_file(pipeline_yml)
    end

    private

    def build_yml
      binding_class = create_binding_class

      resource_entries = create_entries_from_template(binding_class, resource_template_file)

      common_resource_entries = create_common_entries_from_template(
        binding_class,
        common_resource_template_file
      )

      resource_type_entries = create_resource_types_from_template(
        binding_class,
        resource_type_template_file
      )

      groups, job_entries = create_groups_and_jobs_entries(binding_class)

      create_complete_yaml(groups, resource_entries, common_resource_entries, job_entries, resource_type_entries)
    end

    def create_groups_and_jobs_entries(binding_class)
      groups = ''
      all_jobs_entry = [{ 'name' => '000-all', 'jobs' => [], }]
      job_entries = create_entries_from_template(
        binding_class, job_template_file) do |branch, job_entry_yml|
        groups += create_group_entry(branch, job_entry_yml, all_jobs_entry) if group_per_branch
      end

      if group_per_branch
        all_jobs_entry_yaml = YAML.dump(all_jobs_entry).gsub(/^---\n/, '')
        groups = "groups:\n" + all_jobs_entry_yaml + groups
      end
      [groups, job_entries]
    end

    def create_complete_yaml(groups, resource_entries, common_resource_entries, job_entries, resource_type_entries)
      "---\n" \
        "#{groups}" \
        "resources:\n" \
        "#{resource_entries}\n" \
        "#{common_resource_entries}\n" \
        "jobs:\n" \
        "#{job_entries}\n" \
        "resource_types:\n" \
        "#{resource_type_entries}\n"
    end

    def write_pipeline_file(pipeline_yml)
      tmpdir = Dir.mktmpdir
      pipeline_file = "#{tmpdir}/pipeline.yml"
      File.open(pipeline_file, 'w') do |file|
        file.write(pipeline_yml)
      end
      pipeline_file
    end

    def create_binding_class
      binding_class = Class.new
      binding_class.class_eval(
        <<-BINDING_CLASS
          attr_accessor :uri, :branch_name
          def get_binding
             binding()
          end
      BINDING_CLASS
      )
      binding_class
    end

    def create_group_entry(branch, job_entry_yml, all_jobs_entry)
      job_entry_hashes = YAML.load(job_entry_yml)
      job_names = job_entry_hashes.reduce([]) do |names, job|
        names << job.fetch('name')
      end
      all_jobs_entry.first.fetch('jobs').concat(job_names)
      group_entry_yaml = YAML.dump([{ 'name' => branch, 'jobs' => job_names, }])
      group_entry_yaml.gsub(/^---\n/, '')
    end

    def create_common_entries_from_template(binding_class, template_file)
      return '' unless template_file
      template = open(template_file).read
      erb_binding = binding_class.new
      erb_binding.uri = git_uri
      ERB.new(template).result(erb_binding.get_binding)
    end

    def create_entries_from_template(binding_class, template_file, &block)
      template = open(template_file).read

      branches.reduce('') do |entries_memo, branch|
        erb_binding = binding_class.new
        erb_binding.uri = git_uri
        erb_binding.branch_name = branch
        entry_yml = ERB.new(template).result(erb_binding.get_binding)
        yield(branch, entry_yml) if block
        entries_memo.concat(entry_yml)
      end
    end

    def create_resource_types_from_template(binding_class, template_file)
      return '' unless template_file
      template = open(template_file).read
      erb_binding = binding_class.new
      erb_binding.uri = git_uri
      ERB.new(template).result(erb_binding.get_binding)
    end
  end
end
