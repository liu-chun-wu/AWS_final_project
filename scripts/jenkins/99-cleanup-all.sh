#!/bin/bash
#
# 99-cleanup-all.sh
# Tear down demo/prod AWS resources for this project in one go.
#
# What it removes (per selected scope):
#   - CloudFormation/SAM stack(s): flask-demo-backend, flask-prod-backend
#   - ECR repository: aws-lab-flask-demo (force deletes images)
#   - Optional: Jenkins EC2 instance info file cleanup (local only)
#
# Requirements:
#   - AWS CLI v2 configured with valid credentials
#   - Permissions: cloudformation:DeleteStack, ecr:DeleteRepository,
#     ecr:ListImages, ecr:BatchDeleteImage, logs:DeleteLogGroup (implicit via stack delete)
#
# Usage:
#   ./scripts/jenkins/99-cleanup-all.sh --demo        # remove demo stack + repo
#   ./scripts/jenkins/99-cleanup-all.sh --prod        # remove prod stack + repo
#   ./scripts/jenkins/99-cleanup-all.sh --all         # demo + prod + repo
#   Optional: --region us-east-1 (default)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env-common.sh"

REGION="${PIPELINE_AWS_REGION:-us-east-1}"
SCOPE=""
ECR_REPO="${PIPELINE_ECR_REPO:-aws-lab-flask-demo}"
DEMO_STACK="${PIPELINE_STACK_DEMO:-flask-demo-backend}"
PROD_STACK="${PIPELINE_STACK_PROD:-flask-prod-backend}"

usage() {
  cat <<EOF
Usage: $0 [--demo|--prod|--all] [--region REGION]

Examples:
  $0 --demo
  $0 --prod --region us-east-1
  $0 --all
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --demo) SCOPE="demo"; shift ;;
    --prod) SCOPE="prod"; shift ;;
    --all)  SCOPE="all"; shift ;;
    --region) REGION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$SCOPE" ]]; then
  echo "Error: choose one of --demo | --prod | --all"
  usage
  exit 1
fi

confirm() {
  read -r -p "Proceed with cleanup in region '${REGION}' (y/N)? " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]]
}

echo "Cleanup scope: $SCOPE"
echo "AWS Region:    $REGION"
echo "ECR Repo:      $ECR_REPO"
echo
confirm || { echo "Aborted."; exit 1; }

delete_stack() {
  local stack="$1"
  if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleting CloudFormation stack: $stack"
    aws cloudformation delete-stack --stack-name "$stack" --region "$REGION"
    echo "Waiting for delete to finish..."
    aws cloudformation wait stack-delete-complete --stack-name "$stack" --region "$REGION" || true
  else
    echo "Stack not found (skip): $stack"
  fi
}

delete_ecr_repo() {
  if aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$REGION" >/dev/null 2>&1; then
    echo "Force deleting ECR repository: $ECR_REPO"
    aws ecr delete-repository --repository-name "$ECR_REPO" --region "$REGION" --force
  else
    echo "ECR repository not found (skip): $ECR_REPO"
  fi
}

case "$SCOPE" in
  demo) delete_stack "$DEMO_STACK";;
  prod) delete_stack "$PROD_STACK";;
  all)  delete_stack "$DEMO_STACK"; delete_stack "$PROD_STACK";;
esac

# Always delete shared repo for the selected scope
delete_ecr_repo

echo "Cleanup complete."
