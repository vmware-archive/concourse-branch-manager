# Concourse Branch Manager

Automatically build arbitrary branches on [Concourse CI](http://concourse.ci/) without relying on Github pull requests.

See and vote for [this issue](https://github.com/concourse/concourse/issues/239) to get official support for building arbitrary branches without pull requests added to Concourse.

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

* In your Concourse pipeline, you will add a git resource and a job which will run
  Concourse Branch Manager, and specify the necessary parameters, including credentials
  to manage your Concourse instance.
* When the job runs its tasks, it will dynamically create/update a new pipeline which will
  contain resources and jobs for all your dynamically processed branches.
* The resources and jobs/plans/tasks which are automatically created in the pipeline
  are configurable to do whatever is needed for your particular situation and
  build/deployment environment.

## Setup and Usage

### 1. Edit and update your Concourse pipeline to add the three required concourse-branch-manager resources

* Add the following resources to your Concourse pipeline YAML file:

```yaml
- name: concourse-branch-manager
  type: git
  source:
    uri: https://github.com/pivotaltracker/concourse-branch-manager.git
    branch: master
    ignore_paths: [Gemfile, Gemfile.lock]

# This `git-branches` input resource determines which branches will be processed
- name: branch-manager-git-branches
  type: git-branches
  source:
    # Set this to the uri of your repo for which you want to dynamically build arbitrary branches
    uri: https://github.com/mygithubuser/my-repo
    branch_regexp: ".*"
    max_branches: 20

# This repo containing your resource/job templates can be the same repo as
# the one in the git-branches resource above, but it doesn't have to be
- name: branch-manager-templates
  type: git
  source:
    uri: https://github.com/mygithubuser/my-template-repo
    branch: master
    paths: [ci/templates/*]
```

* The `concourse-branch-manager` resource will always point to the `concourse-branch-manager`
  public repo on github, and should look exactly as the above example.  This is where the logic
  for the branch-building task lives.

* Set the `uri` of the `branch-manager-git-branches` resource with the uri of your
  repo for which you want to dynamically build arbitrary branches.

* Set the `uri` of the `branch-manager-templates` resource with the uri of your
  your `git` resource containing your resource/job templates for building branches. NOTE: This
  may both point to the same git repo as your `git-branches` resource, but it doesn't have to.

### 2. Edit and update your Concourse pipeline to add the branch-manager job:

* Add the following job to your Concourse pipeline YAML file:

```yaml
- name: branch-manager
  serial: true
  plan:
  - get: concourse-branch-manager
    params: {depth: 20}
    trigger: true
  - get: git-branches
    resource: branch-manager-git-branches
    trigger: true
  - get: template-repo
    resource: branch-manager-templates
    params: {depth: 20}
    trigger: true
  - task: manage-branches
    file: concourse-branch-manager/tasks/manage-branches.yml
    config:
      params:
        BRANCH_RESOURCE_TEMPLATE: template-repo/ci/templates/my-repo-branch-resource-template.yml.erb
        BRANCH_JOB_TEMPLATE: template-repo/ci/templates/my-repo-branch-job-template.yml.erb
        CONCOURSE_URL: {{CONCOURSE_URL}}
        CONCOURSE_USERNAME: {{CONCOURSE_USERNAME}}
        CONCOURSE_PASSWORD: {{CONCOURSE_PASSWORD}}
```

You may specify the `CONCOURSE_*` params directly in your pipeline YAML file, but
since they are sensitive credentials, you should handle them via Concourse's
support for [template variables](http://concourse.ci/fly-cli.html#parameters).

The `BRANCH_RESOURCE_TEMPLATE` and `BRANCH_JOB_TEMPLATE` parameters are paths
to ERB templates which will be used to dynamically generate a resource and
job for each of your branches.  These templates can
live in your managed repo, but they don't have to - you could add an additional
resource to the `branch-manager` job to contain them.  More details on this below...

***TODO: Document PIPELINE_LOAD_VARS_FROM_N params***
***TODO: Document PIPELINE_NAME param***
***TODO: Document PIPELINE_COMMON_RESOURCES_TEMPLATE param***
***TODO: Document GROUP_PER_BRANCH param***

### 3. Edit and update your Concourse pipeline to add the branch-manager group (optional):

```yaml
- name: branch-manager
  jobs:
  - branch-manager
```

### 4. Create a YAML ERB templates for your resource and job which will be run for each branch

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
  params: {depth: 20}
  trigger: true
- task: my-repo-branch-task
  file: my-repo-branch/ci/tasks/my-repo-branch-task.yml
  config:
    params:
      BRANCH_NAME: <%= branch_name %>
```

### 5. Create/Update the Concourse pipeline

* Update your Concourse pipeline with the new resources and job
  using the [`fly set-pipeline`](http://concourse.ci/fly-cli.html#fly-set-pipeline)
  command.

## Alternate configuration options

The implementation above is flexible.  Based on your situation, you can any combination of one or more
pipelines, `git-branches` resources, template `git` resources, `branch-manager` jobs, resource templates,
and job templates.

For example, you can have one pipeline per branch, one pipeline with multiple branches, multiple
pipelines with multiple branches, multiple jobs with different templates using different resources -
whatever works for you.

The resource naming is also flexible to allow you to have multiple `git-branches` or template `git`
resources in the same pipeline YAML file.  The only requirement is that the `get` entries in your
task must be named `concourse-branch-manager`, `git-branches`, and `template-repo`, since these
are referred to by the task branch-building logic.

## Live Example

There is a working example pipeline which points to
[example templates and a dummy task in the concourse-branch-manager project repo](https://github.com/pivotaltracker/concourse-branch-manager/blob/master/examples))

To try it out yourself:

1. (at the beginning of the day) Login to fly and save credentials in a `ci` target:

    ```
    fly login --target=ci --concourse-url=https://my-concourse-server
    ```

2. Clone a local copy of the
   [`branch-manager-example` repo](https://github.com/pivotaltracker/concourse-branch-manager).
   Note that this has all the Concourse config in an `examples` directory, but in your actual projects
   you may want to want to put this in a `ci` directory by convention.

3. Create a `secrets.yml` file containing the vars specifying the uri and credentials of your Concourse
   server.  Put this some where secret and don't check it in!  For convenience, `secrets.yml` in the root
   of this repo is gitignored, so you can put it there if you want:

    ```
    # secrets.yml
    CONCOURSE_URL: https://my-concourse-server.example.com
    CONCOURSE_USERNAME: my-basic-auth-concourse-username
    CONCOURSE_PASSWORD: my-basic-auth-concourse-password
    ```

4. Use the `fly set-pipeline` command to create/update the `branch-manager-example` pipeline:

    ```
    fly --target=ci set-pipeline --config=examples/pipelines/branch-manager-example.yml --load-vars-from=secrets.yml --pipeline=branch-manager-example
    ```

5. (first time only) Use the `fly unpause-pipeline` commmand to unpause the pipeline the first
   time it is created (or just click unpause in the Concourse UI):

   ```
   fly --target=ci unpause-pipeline --pipeline=branch-manager-example
   ```

6. Go to your Concourse UI (e.g. `https://my-concourse-server.example.com`), and select
   the `branch-manager-example` pipeline from the upper-left hamburger menu.

7. It should successfully build automatically in a few seconds and go green

8. Refresh the page, and select the autocreated `branch-manager` pipeline from the upper-left
   hamburger menu.  It should contain some of the dummy branches on the `concourse-branch-manager`
   repo.  They should also all successfully build after a few seconds.

That's it!  Use this as a template and example for using concourse-branch-manager in your
own project!

## Dealing with Concourse UI issues due to many branches/groups

* It is recommended that you keep the number of branches limited.  The git-branches-resource
  resource by default limits you to 20, but the Concourse UI starts having layout issues
  with fewer than that.  The biggest problem is z-index issues that prevent usage of the
  pipelines menu.
* [This issue against Concourse ATC](https://github.com/concourse/atc/issues/39)
  (the Concourse UI) reports these issues, and contains a javascript bookmarklet
  that makes some hacks to fix the issues.  The recommended fix by the concourse team
  would be to make the groups scrollable like the build numbers at the top of a build
  page.  A pull request would be welcome ;)
