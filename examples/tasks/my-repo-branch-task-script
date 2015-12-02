#!/usr/bin/env sh

echo "In my-repo-branch-task-script, running `git status` for branch '${BRANCH_NAME}'..."

cd my-repo-branch
git status
git branch -a
cd ..

echo "Pipeline load-vars-from values:"
echo "  EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY: $EXAMPLE_LOAD_VARS_FROM_CONFIG_KEY"
echo "  EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY: $EXAMPLE_LOAD_VARS_FROM_CREDENTIALS_KEY"
echo
echo "First line of readme from PIPELINE_COMMON_RESOURCES_TEMPLATE entry:"
echo "'$(head -n 1 my-repo-common-resource/README.md)'"
echo
echo "Successfully ran my-repo-branch-task-script for branch '${BRANCH_NAME}'!"
