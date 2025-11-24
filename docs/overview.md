# Project Overview

This repository demonstrates a full learner-lab friendly CI/CD flow for a Flask API. You iterate in three layers:

1. **Manual scripts** (`scripts/local/`) – prove each change with pytest and Docker builds, then run the shared CI/CD scripts directly for a single deployment.
2. **Local Jenkins** (`scripts/jenkins/40-setup-jenkins-local.sh`) – run the same Jenkinsfiles in a Dockerized Jenkins controller using your local AWS credentials.
3. **EC2 Jenkins** (`scripts/jenkins/41-setup-jenkins-ec2.sh`) – provision a long-lived Jenkins host that reuses those Jenkinsfiles and authenticates via the instance profile.

The pipeline always follows *Prove → Codify → Automate*: verify locally, codify the pipeline, then let Jenkins run it.

## Branch Strategy

| Branch  | Pipeline Mode | AWS Actions | Use Case |
|---------|---------------|-------------|----------|
| `Jeffery` | Auto CI (webhook) + manual CD | Manual `flask-cd` deploy (typically demo-backend) | Daily development & testing |
| `main`    | Auto CI (webhook) + manual CD | Manual `flask-cd` deploy with prod parameters | Production releases |

Pushes to `Jeffery` must stay green before requesting review. Merges to `main` kick off the CI steps; run `flask-cd` manually to deploy the approved image to Lambda/API Gateway.

## Key Directories

- `backend/` – production-ready service code and tests.
- `demo-backend/` – immutable demo used to validate CI/CD logic.
- `ci/` – Jenkinsfile-CI and Jenkinsfile-CD; Jenkins always pulls these from Git.
- `scripts/local/` – developer-only helpers for pytest and Docker validation.
- `scripts/jenkins/` – shared CI/CD scripts plus Jenkins provisioning utilities.
- `aws/` – SAM template + config files for demo/production deployments.
- `docs/` – this concise reference set (see `scripts.md`, `jenkins.md`, `troubleshooting.md`, `validation.md`).

## Prerequisites

- Python 3.11 and Docker Desktop.
- AWS CLI v2 + SAM CLI configured with a Learner Lab profile (us-east-1).
- Access to a GitHub repository with the Jenkins webhook enabled.

Once prerequisites are installed, run `./scripts/local/test-local.sh --demo` to confirm the project boots before making code changes.
