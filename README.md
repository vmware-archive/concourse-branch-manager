# Concourse Branch Manager

Automatically build arbitrary branches on [Concourse CI](http://concourse.ci/).

![Branches](https://cdn.rawgit.com/pivotaltracker/concourse-branch-manager/master/branches.svg)

## Overview

This is a Concourse build task to find all existing branch names which match selected (1) criteria.

Then, based on a YAML .erb template (2) a job + build plan will be dynamically created and added
to the pipeline, using the concourse Fly CLI to create it "on the fly" (no pun intended).

* (1) The "selected" branches can be based a regex param to the task, which can be based on
anything- a ref out of a github pull request json payload, a regex to build all branches
starting with a string (e.g. feature-, release-candidate-, etc).

* (2) the specified job yml.erb template can build whatever job/plan it needs, and the name
of the dynamically-selected git branch will be passed as a param, to be interpolated into
the YAML via erb
