# Concourse Branch Manager

Automatically build arbitrary branches on [Concourse CI](http://concourse.ci/).

![Branches](https://cdn.rawgit.com/pivotaltracker/concourse-branch-manager/master/branches.svg)

## Overview

This is a Concourse build task to find all existing branch names which match selected (1) criteria.

Then, a `branch-manager` pipeline will be dynamically created/updated,
using the concourse Fly CLI to create it "on the fly" (no pun intended),
which will contain for a job + build plan for each branch, based on
YAML ERB templates (2).

It is intended to be used with the
[Concourse git-branches-resource](https://github.com/pivotaltracker/git-branches-resource) (3)
to determine when and which branches should be built.  However, any resource that
fulfills the same input contract at the git-branches-resource can be used.

* (1) The "selected" branches can be based a regex config option passed
  to the git-branches-resource (3) or other resource which fulfills the
  resource 'input' contract to write out a `git-branches.json` containing
  a hash with a `uri` to the repo, and an array of `branches`.
  This list of branches can be controlled with a regex
  (e.g. all branches starting with a string like feature-, release-candidate-, etc),
  and also limit the maximum number of branches listed.  See the
  [Concourse git-branches-resource](https://github.com/pivotaltracker/git-branches-resource)
   documentation for more details.  ***NOTE:*** *In the future, support will be added
   for automatically building branches for GitHub pull requests, via this same
   `git-branches.json` input resource interface.*

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

# This `git-branches` input resource determines which branches will be processed
- name: myrepo-git-branches
  type: git-branches
  source:
    uri: https://github.com/mygithubuser/myrepo
    branch_regexp: ".*"
    max_branches: 20

# The repo containing your resource/job templates can be the same repo as
# the one in the git-branches resource above, but it doesn't have to be
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

Replace the `resource` entries with the ones you created above.  Replace `resource: myrepo-git-branches`
with the name of your `git-branches` resource, and replace `resource: mytemplaterepo`
with the name of your `git` resource containing your templates.  These may both
point to the same git repo, but they don't have to.

You may specify the `CONCOURSE_*` params directly in your pipeline YAML file, but
since they are sensitive credentials, you should handle them via Concourse's
support for [template variables](http://concourse.ci/fly-cli.html#parameters).

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
the `uri` and `branch_name` variables, which are automatically set to contain the
repo uri and name of the branch which was automatically detected and processed,
and for which builds should be triggered.

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
  uri: <%= uri %>
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
  trigger: true
- task: my-repo-branch-task
  file: my-repo-branch/examples/tasks/my-repo-branch-task.yml
  config:
    params:
      BRANCH_NAME: <%= branch_name %>
```
