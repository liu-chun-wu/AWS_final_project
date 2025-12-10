#!/usr/bin/env bash
# Centralized defaults for pipeline parameters.
# Override any value by exporting the corresponding PIPELINE_* variable before running.

# Repository / image naming
export PIPELINE_IMAGE_NAME="${PIPELINE_IMAGE_NAME:-aws-final-project-repo}"
export PIPELINE_ECR_REPO="${PIPELINE_ECR_REPO:-$PIPELINE_IMAGE_NAME}"

# AWS settings
export PIPELINE_AWS_REGION="${PIPELINE_AWS_REGION:-us-east-1}"

# Branch policy
export PIPELINE_BRANCH_ALLOWED="${PIPELINE_BRANCH_ALLOWED:-Jeffery}"

# Stack and SAM configs
export PIPELINE_STACK_DEMO="${PIPELINE_STACK_DEMO:-aws-final-project-demo}"
export PIPELINE_STACK_PROD="${PIPELINE_STACK_PROD:-aws-final-project-prod}"
export PIPELINE_SAM_CONFIG_DEMO="${PIPELINE_SAM_CONFIG_DEMO:-samconfig-demo.toml}"
export PIPELINE_SAM_CONFIG_PROD="${PIPELINE_SAM_CONFIG_PROD:-samconfig-prod.toml}"

# Tag prefixes per environment (shared ECR repo)
export PIPELINE_TAG_PREFIX_DEMO="${PIPELINE_TAG_PREFIX_DEMO:-demo}"
export PIPELINE_TAG_PREFIX_PROD="${PIPELINE_TAG_PREFIX_PROD:-prod}"

# GitHub / Jenkins metadata
export PIPELINE_GITHUB_REPO="${PIPELINE_GITHUB_REPO:-https://github.com/liu-chun-wu/AWS_final_project.git}"
export PIPELINE_CI_JOB="${PIPELINE_CI_JOB:-aws-final-project-ci}"
export PIPELINE_CD_JOB="${PIPELINE_CD_JOB:-aws-final-project-cd}"

# Helper to pretty print (optional)
print_pipeline_config() {
  cat <<'EOF'
Pipeline config (overridable via PIPELINE_* env vars):
  IMAGE_NAME        = '"${PIPELINE_IMAGE_NAME}"'
  ECR_REPO          = '"${PIPELINE_ECR_REPO}"'
  AWS_REGION        = '"${PIPELINE_AWS_REGION}"'
  BRANCH_ALLOWED    = '"${PIPELINE_BRANCH_ALLOWED}"'
  STACK_DEMO        = '"${PIPELINE_STACK_DEMO}"'
  STACK_PROD        = '"${PIPELINE_STACK_PROD}"'
  SAM_CONFIG_DEMO   = '"${PIPELINE_SAM_CONFIG_DEMO}"'
  SAM_CONFIG_PROD   = '"${PIPELINE_SAM_CONFIG_PROD}"'
  GITHUB_REPO       = '"${PIPELINE_GITHUB_REPO}"'
  CI_JOB_NAME       = '"${PIPELINE_CI_JOB}"'
  CD_JOB_NAME       = '"${PIPELINE_CD_JOB}"'
EOF
}
