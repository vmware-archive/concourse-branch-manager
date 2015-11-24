require 'yaml'
require 'tmpdir'
require 'erb'

module Cbm
  # Generates pipeline yml based on branches
  class PipelineGenerator
    include Logger
    attr_reader :uri, :branches, :resource_template_file, :job_template_file

    def initialize(uri, branches, resource_template_file, job_template_file)
      @uri = uri
      @branches = branches
      @resource_template_file = resource_template_file
      @job_template_file = job_template_file
    end

    def generate
      log 'Generating pipeline file...'

      binding_class = create_binding_class

      resource_entries = create_entries_from_template(binding_class, resource_template_file)
      job_entries = create_entries_from_template(binding_class, job_template_file)

      pipeline = {
        'resources' => resource_entries,
        'jobs' => job_entries,
      }

      pipeline_yml = YAML.dump(pipeline)

      log 'Generated pipeline yml:'
      log '-' * 80
      log pipeline_yml
      log '-' * 80

      write_pipeline_file(pipeline_yml)
    end

    private

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

    def create_entries_from_template(binding_class, template_file)
      template = open(template_file).read
      branches.reduce([]) do |entries_memo, branch|
        erb_binding = binding_class.new
        erb_binding.uri = uri
        erb_binding.branch_name = branch
        entry_yml = ERB.new(template).result(erb_binding.get_binding)
        entry = YAML.load(entry_yml)
        entries_memo << entry
      end
    end
  end
end
