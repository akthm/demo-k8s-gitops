#!/bin/bash
#
# This script exports environment variables for the local development
# or testing environment.
#
# IMPORTANT: This script must be "sourced" to work, not executed.
# Run: source ./local-exports.sh
#

# --- Cluster Configuration ---
# Sets the cluster provider (e.g., "kind", "aws", "gcp")
export CLUSTER_PROVIDER="kind"

# Sets a default cluster name if one isn't already set in the shell
export CLUSTER_NAME="${CLUSTER_NAME:-dev-platform}"


# --- GitOps Repository Configuration ---
# The URL to the GitOps repository that ArgoCD will watch
export GIT_REPO_URL="https://github.com/akthm/demo-k8s-gitops"

# The branch in the repo to watch
export GIT_BRANCH="main"

# The path within the repo where the "App of Apps" manifests are located
export PLATFORM_APPS_PATH="apps/staging"

# You can add more variables here as needed
# export MY_OTHER_VAR="some-value"

echo "Loaded environment variables for: $CLUSTER_NAME"
echo "DEBUG: GitOps repo is set to $GIT_REPO_URL on branch $GIT_BRANCH, watching path $PLATFORM_APPS_PATH"
