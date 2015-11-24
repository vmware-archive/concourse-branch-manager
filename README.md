# Concourse Branch Manager

Automatically build arbitrary branches on [Concourse CI](http://concourse.ci/).

![Branches](https://cdn.rawgit.com/pivotaltracker/concourse-branch-manager/master/branches.svg)

## Overview

This is a Concourse build task to find all existing branch names which match selected (1) criteria.

Then, a `branch-manager` pipeline will be dynamically created/updated,
using the concourse Fly CLI to create it "on the fly" (no pun intended),
which will contain for a job + build plan for each branch, based on
YAML ERB templates (2).

* (1) The "selected" branches can be based a regex param to the task, which can be based on
  anything- a ref out of a github pull request json payload, a regex to build all branches
  starting with a string (e.g. feature-, release-candidate-, etc).

* (2) the specified resource and job YAML ERB templates can contain whatever job/plan
  processing is needed, and the name of the dynamically-selected git branch will be passed as a param,
  to be interpolated into the YAML via ERB.

## How it works

* In your main Concourse pipeline, you will add a git resource and a job which will run
  Concourse Branch Manager, and specify the necessary parameters, including credentials
  to manage your Concourse instance.
* When the job runs its tasks, it will dynamically create/update a new pipeline which will
  contain resources and jobs for all your dynamically processed branches.
* The resources and jobs/plans/tasks which are automatically created in the pipeline
  are configurable to do whatever is needed for your particular situation and
  build/deployment environment.

## Setup and Usage

### 1. Edit and update your main Concourse pipeline to add the concourse-branch-manager resource and job

* Add the following resources to your main Concourse pipeline YAML file:

```yaml
- name: concourse-branch-manager
  type: git
  source:
    uri: https://github.com/pivotaltracker/concourse-branch-manager.git
    branch: master
    ignore_paths: [Gemfile, Gemfile.lock]

- name: myrepo-git-branches
  type: git-branches
  source:
    uri: https://github.com/mygithubuser/myrepo
# TODO: move implementation to resource
#    max_branches: 20 # Optional, the maximum number of branches to process
#    branch_regexp: .* # Optional, replace with a regular expression matching the branches you wish to build

- name: mytemplaterepo
  type: git
  source:
    uri: https://github.com/mygithubuser/mytemplaterepo
    branch: hacking
    paths: [templates/*]
```

Set the `name` and `uri` of `managed-repo-myrepo` with the name and uri of the
repo for which you want to dynamically build arbitrary branches.

* Add the following job to your main Concourse pipeline YAML file:

```yaml
- name: branch-manager
  serial: true
  plan:
  - get: concourse-branch-manager
    params: {depth: 1}
    trigger: true
  - get: git-branches
    resource: myrepo-git-branches
    trigger: true
  - get: template-repo
    resource: mytemplaterepo
    params: {depth: 1}
    trigger: true
  - task: manage-branches
    file: concourse-branch-manager/tasks/manage-branches.yml
    config:
      params:
        BRANCH_RESOURCE_TEMPLATE: template-repo/examples/templates/my-repo-branch-resource-template.yml.erb
        BRANCH_JOB_TEMPLATE: template-repo/examples/templates/my-repo-branch-job-template.yml.erb
        CONCOURSE_URL: {{CONCOURSE_URL}}
        CONCOURSE_USERNAME: {{CONCOURSE_USERNAME}}
        CONCOURSE_PASSWORD: {{CONCOURSE_PASSWORD}}
```

Replace the `resource` entry under the `get: managed-repo` with the name of the `managed-repo-*`
resource you created above.

You may specify the `CONCOURSE_*` params directly in your pipeline YAML file, but
since they are sensitive credentials, you should handle them via Concourse's
support for [template variables](http://concourse.ci/fly-cli.html#parameters).

The `BRANCH_REGEXP` parameter will be used to select the branches you wish to
automatically process.  Only branches with names matching the regular expression will have
a corresponding resource and job created for them.  This parameter is optional,
if omitted it will default to `.*`, which will match all existing branches,
and cause a resource and job to be created for every existing branch.

The `MAX_BRANCHES` parameter defines the maximum number of branches to process. If there
are more than this number of branches matched by the regular expression, it will fail. You
can either increase the number of branches to process, or specify a more restrictive
regular expression.

The `BRANCH_RESOURCE_TEMPLATE` and `BRANCH_JOB_TEMPLATE` parameters are paths
to ERB templates which will be used to dynamically generate a resource and
job for each of your branches.  These templates can
live in your managed repo, but they don't have to - you could add an additional
resource to the `branch-manager` job to contain them.  More details on this below...

* (optional) Add the following group to your main Concourse pipeline YAML file:

```yaml
- name: branch-manager
  jobs:
  - branch-manager
```

* Update your main Concourse pipeline with the new resources and job
  using the [`fly set-pipeline`](http://concourse.ci/fly-cli.html#fly-set-pipeline)
  command.

### 2. Create a YAML ERB templates for your resource and job which will be run for each branch

Each arbitrary branch which is dynamically detected will have a Concourse
[resource]() automatically created for it, and a Concourse
[job](http://concourse.ci/configuring-jobs.html), [build plan](http://concourse.ci/build-plans.html),
and [task](http://concourse.ci/task-step.html) will also be automatically created to process it.

You have control over what this resource and job do by providing
[ERB](http://apidock.com/ruby/ERB) templates which will be used to build
separate resource and job entries in the generated pipeline for each branch
which is processed.

The path to your ERB templates is specified in the `BRANCH_RESOURCE_TEMPLATE` and
`BRANCH_JOB_TEMPLATE` parameters, as documented above.  They are paths
to ERB templates which will be used to dynamically generate a resource and
job for each of your branches. These templates can
live in your managed repo, but they don't have to - you could add an additional
resource to the `branch-manager` job to contain them.

The only requirement for these ERB templates is that they use ERB to interpolate
the `branch_name` variable, which is automatically set to contain the
name of the branch which was automatically detected and processed.

And, of course, you must create and properly reference a
[task configuration and associated script](http://concourse.ci/running-tasks.html#configuring-tasks),
as well as any additional resources you need,
to do the actual work of your job.  This can be whatever you want - using a
Concourse git or s3 resource output to push a branch or s3 artifact, which
can then be used by other hardcoded jobs in your pipeline. Here is an example
[task configuration](https://github.com/pivotaltracker/concourse-branch-manager/blob/master/examples/tasks/my-repo-branch-task.yml) and
[script](https://github.com/pivotaltracker/concourse-branch-manager/blob/master/examples/tasks/my-repo-branch-task-script)
from the concourse-branch-manager project itself.

Here is an example branch resource template (this is an
[actual example from the concourse-branch-manager project itself](https://github.com/pivotaltracker/concourse-branch-manager/blob/master/examples/templates/my-repo-branch-resource-template.yml.erb)):

```yaml
name: my-repo-branch-<%= branch_name %>
type: git
source:
  uri: https://github.com/pivotaltracker/concourse-branch-manager.git
  branch: <%= branch_name %>
```

And here is an example branch job template (this is an
[actual example from the concourse-branch-manager project itself](https://github.com/pivotaltracker/concourse-branch-manager/blob/master/examples/templates/my-repo-branch-job-template.yml.erb)):

```yaml
name: my-repo-branch-job-<%= branch_name %>
plan:
- get: my-repo-branch
  resource: my-repo-branch-<%= branch_name %>
  params: {depth: 1}
- task: my-repo-branch-task
  file: my-repo-branch/examples/tasks/my-repo-branch-task.yml
  config:
    params:
      BRANCH_NAME: <%= branch_name %>
```

