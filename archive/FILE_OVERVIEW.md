# AWS Learner Lab Flask CI/CD Demo – File-by-File Overview

This document explains the purpose and relationships of **every file and directory** under `AWS_final_project-Jeffery_2`. It is written as a guide for someone new to the project who wants to understand how the Flask demo backend, production backend, CI/CD pipeline, scripts, and AWS infrastructure all fit together.

---

## Repository Root

Path: `AWS_final_project-Jeffery_2/`

- `.gitignore`  
  Ignores Python bytecode (`__pycache__`), virtual environments (`.venv`), build artifacts, Docker artifacts, and common IDE/editor files. Keeps the repository clean and ensures only source and configuration are committed.

- `.jenkins-ec2-demo.info`  
  Small metadata file used by the Jenkins EC2 helper scripts (`scripts/jenkins/41-setup-jenkins-ec2.sh`, etc.). Typically stores information like the EC2 instance ID, public IP, or other identifiers so that start/stop/status scripts know which EC2 instance is “the Jenkins box” to manage.

- `AGENTS.md`  
  Instructions for AI coding assistants working inside this repository. Describes:
  - Where the main code lives (`backend/`, `demo-backend/`).
  - How tests and Docker builds should be run.
  - Expectations for coding style (PEP 8), documentation, and test coverage.
  - CI/CD usage patterns and security expectations (no secrets in source).
  This file does not affect runtime behavior but sets conventions for anyone (or any tool) editing code in this tree.

- `BRANCH_STRATEGY.md`  
  Detailed explanation of how branches map to CI/CD behavior:
  - **Jeffery branch** is the primary development and deployment branch in this lab.
  - CI steps: checkout, branch validation, venv setup, dependency install, tests, Docker build.
  - CD steps: ECR login, Docker push, and SAM-based Lambda deployment.
  The document explains how to work day‑to‑day on `Jeffery`, how production-style flows were historically handled on `main`, and how Jenkins jobs (`flask-ci`, `flask-cd`) are intended to be used.

- `CLAUDE.md`  
  A usage and architecture guide targeted at the Claude Code assistant. It summarizes:
  - Overall project purpose (Flask demo backend + CI/CD to AWS).
  - Phase-based architecture (local Flask → Docker → manual CI/CD → Jenkins → EC2 → full automation).
  - Common developer commands for Python, Docker, Jenkins, and AWS.
  - The high-level project structure and stack (Flask, gunicorn, pytest, Docker, Jenkins, SAM, ECR, Lambda, API Gateway, CloudWatch).
  While addressed to a specific AI tool, it doubles as an in-depth developer onboarding document.

- `COLLABORATION.md`  
  Team-focused collaboration guide. Key content:
  - What each major directory is for (`backend/` is where collaborators add real production code; `demo-backend/` is off-limits and used only to validate CI/CD).
  - How to work on the `Jeffery` branch, run tests locally, and rely on Jenkins CI.
  - When and how production deployments should occur (usually via `flask-cd` after a green pipeline).
  - Guidance on writing tests, keeping them fast, and ensuring CI/CD pipelines remain healthy.

- `README.md`  
  Top-level project readme. It describes:
  - The overall goal: a **learner-lab friendly, production-style CI/CD pipeline** for a Flask REST API.
  - The multi-phase rollout (local Flask → Docker → manual scripts → local Jenkins → EC2 Jenkins → automated webhooks → recovery tooling).
  - Branch-based strategy: `Jeffery` branch uses auto CI + manual CD, with clear roles for `demo-backend/` vs `backend/`.
  - Consolidated project structure, with comments for each directory and key file.
  - Quick start commands for:
    - Local proving scripts (`scripts/local/test-local.sh`, `build-local.sh`).
    - Jenkins and SAM-based manual pipelines (`scripts/jenkins/20-ci-build-and-push.sh`, `31-cd-deploy-sam.sh`, etc.).
  This is the main entry point when you want a narrative overview of what the project does.

- `samconfig.toml`  
  Root-level SAM configuration file (a lighter-weight default) used by some SAM CLI commands. It defines deployment parameters (stack name, region, capabilities) in a reusable, non-interactive configuration. More specialized variants live under `aws/` for demo (`samconfig-demo.toml`) and production (`samconfig-prod.toml`) deployments.

- `test.txt`  
  A tiny text file used as a placeholder or test artifact. It has no impact on any code, scripts, or deployments.

---

## AWS Infrastructure – `aws/`

Path: `aws/`

This directory describes how the backend is deployed to AWS using **AWS SAM** and a containerized Lambda function.

- `template.yaml`  
  The main **SAM template** that defines:
  - A single Lambda function (`FlaskDemoFunction`) using `PackageType: Image`, which points to a Docker image in ECR:
    - `ImageUri` is constructed dynamically using the AWS account ID, region, and an `ImageTag` parameter.
  - An existing IAM role (`LabRole`) to satisfy AWS Learner Lab restrictions (no novel roles created).
  - An API Gateway (`FlaskDemoApi`) with two mapped endpoints:
    - `GET /health` → the Lambda function (health check).
    - `POST /echo` → the Lambda function (echo endpoint).
  - Global function settings such as timeout, memory, architecture, and CORS configuration.
  - Outputs including:
    - API URL (Prod stage).
    - Lambda function ARN.
    - CloudWatch log group name.
    - Direct URLs for `/health` and `/echo`.
  This file is the single source of truth for how the containerized Flask app is deployed and exposed via HTTP.

- `samconfig-demo.toml`  
  SAM configuration specifically for **demo deployments**:
  - Stack name (e.g., `flask-demo-backend`).
  - S3 prefix for packaged artifacts.
  - Region (`us-east-1`).
  - Capabilities (`CAPABILITY_IAM`).
  It is used when deploying the **demo-backend** image, usually via `scripts/jenkins/31-cd-deploy-sam.sh --demo`.

- `samconfig-demo.toml.bak`  
  Backup of an earlier or alternative demo SAM configuration. Kept for reference or rollback in case the main file is accidentally modified; not consumed directly by scripts or Jenkins.

- `samconfig-prod.toml`  
  SAM configuration for **production-style deployments**:
  - Stack name (`flask-prod-backend`).
  - S3 prefix for production.
  - Same region and capabilities as the demo config.
  Intended to be used when deploying the **production backend** from `backend/` instead of the demo service.

- `samconfig.toml`  
  A generic SAM configuration for the default profile. Similar in structure to the demo/prod variants but used as a default fallback; scripts typically rely on the more explicit `samconfig-demo.toml` / `samconfig-prod.toml`.

---

## Production Backend – `backend/`

Path: `backend/`

This is the **production backend** with integrated AI generation capabilities from the NeoYeh implementation.

**Integration Status:** Complete as of 2025-12-09
- NeoYeh AI generation backend successfully integrated into Jeffery_2 CI/CD template
- All 17 tests passing (12 unit + 5 integration)
- CI/CD compatible without modifications to Jenkinsfiles or SAM templates

- `README.md`
  Comprehensive documentation for the AI generation service:
  - Documents all 5 API endpoints: `/health`, `/generate-image`, `/generate-audio`, `/audio-callback`, `/history`
  - Explains required environment variables (HuggingFace token, Suno token, S3 bucket, DynamoDB table)
  - Details AWS resource requirements (S3 bucket, DynamoDB table with proper schema)
  - Includes troubleshooting section for common integration issues
  - CI/CD workflow documentation for Jeffery branch development and production deployment

- `Dockerfile`
  Dockerfile for the **AI generation backend** container:
  - Base image: `python:3.11-slim`.
  - Copies AWS Lambda Web Adapter from `public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4` into the Lambda extensions directory.
  - Sets working directory to `/app`.
  - Copies `requirements.txt`, installs dependencies including boto3, requests, Pillow.
  - Copies the application source from `src/` into the image.
  - Exposes port `8000` and sets `PORT=8000` for the web adapter.
  - Runs `gunicorn` as the production WSGI server with:
    - Single worker (`--workers 1`).
    - **Timeout of 300 seconds (5 minutes)** for AI API calls (increased from 60s).
    - Entry point `src.app:create_app()` using application factory pattern.
  This image is built for Lambda compatibility via the pipeline and can be deployed with SAM.

- `requirements.txt`
  Python dependencies for the AI generation backend:
  - `Flask==3.0.0` – web framework (matches template version).
  - `gunicorn==21.2.0` – production WSGI server (matches template version).
  - `pytest==7.4.3` – testing framework (matches template version).
  - `boto3==1.34.0` – AWS SDK for S3 and DynamoDB operations.
  - `python-dotenv==1.0.0` – environment variable management.
  - `requests==2.31.0` – HTTP client for external APIs (HuggingFace, Suno).
  - `Pillow==10.2.0` – image processing library for validating generated images.
  - `discord.py==2.3.2` and `aiohttp==3.9.1` – Discord bot support (optional, not used in Lambda).

- `src/app.py`
  Complete AI generation Flask application:
  - Uses application factory pattern: `create_app(config=None)`.
  - Initializes AWS clients (S3) and loads API credentials from environment variables.
  - Implements 5 endpoints:
    - `GET /health` – returns `{"status": "ok", "service": "production-backend"}`.
    - `POST /generate-image` – generates AI images via HuggingFace Stable Diffusion XL, uploads to S3, saves to DynamoDB, returns presigned URL.
    - `POST /generate-audio` – initiates async music generation via Suno API, returns task ID and presigned URL.
    - `POST /audio-callback` – webhook endpoint for Suno to deliver completed audio files.
    - `GET /history?user_id=xxx` – retrieves generation history from DynamoDB for a given user.
  - Error handling for missing prompts, API failures, S3/DynamoDB errors.
  - Contains a `__main__` block for local development.

- `src/db.py`
  DynamoDB helper module:
  - Initializes DynamoDB resource using boto3 with region and table name from environment variables.
  - `insert_record()` – adds generation records (image/audio) with UUID, timestamp, user_id, prompt, file URL, and type.
  - `get_history(user_id)` – queries all records for a user and returns simplified list with prompt, URL, and type.
  - `get_record(user_id, record_id)` – fetches a single record by composite key.
  - Designed for the `UserRecords` table schema with partition key `user_id` and sort key `record_id`.

- `tests/__init__.py`
  - Empty file marking `tests/` as a Python package.

- `tests/unit/__init__.py`
  - Empty package initializer.

- `tests/unit/test_health.py`
  Unit tests for the `/health` endpoint (5 tests):
  - Verifies 200 status code, JSON content type, correct response structure and values.
  - Ensures only GET method is accepted (POST/PUT/DELETE return 405).

- `tests/unit/test_generate_image.py`
  Unit tests for the `/generate-image` endpoint (4 tests):
  - Validates 400 errors for missing or empty prompts.
  - Confirms endpoint exists and accepts POST.
  - Ensures only POST method is accepted.

- `tests/unit/test_generate_audio.py`
  Unit tests for the `/generate-audio` endpoint (3 tests):
  - Validates 400 error for missing prompt.
  - Confirms endpoint exists and accepts POST.
  - Ensures only POST method is accepted.

- `tests/integration/__init__.py`
  - Empty package initializer.

- `tests/integration/test_api.py`
  Integration tests for complete API surface (5 tests):
  - Verifies all endpoints exist and are routable (not 404).
  - Tests health check integration.
  - Validates HTTP method restrictions across all endpoints.
  - Confirms JSON response format for all endpoints.
  - Tests error handling for invalid requests (missing prompts return 400 with error messages).

**Test Coverage:** 17 tests total (12 unit + 5 integration), all passing.
**Integration Strategy:** Tests use basic validation without requiring real AWS resources or API tokens, ensuring CI/CD can run tests without external dependencies.

---

## Demo Backend – `demo-backend/`

Path: `demo-backend/`

This is a **fully implemented, tested, and working demo backend** used solely to validate the CI/CD pipeline. It is intentionally simple but production‑style.

- `Dockerfile`  
  Similar to the production Dockerfile but tailored for the demo app:
  - Uses a Python base image.
  - Installs dependencies from `requirements.txt`.
  - Copies the demo app source under `src/`.
  - Uses gunicorn to serve the Flask app over port 8000 in a containerized environment. The container is built and pushed to ECR for Lambda use.

- `requirements.txt`  
  Lists the Python dependencies for the demo backend (Flask, gunicorn, pytest). Mirrors the production dependencies, ensuring both services can be treated similarly in CI/CD.

- `src/__init__.py`  
  Empty file making `src` a Python package; necessary so `from src.app import create_app` works in tests.

- `src/app.py`  
  Complete, production-style Flask app implementing the demo service:
  - Uses an **application factory** (`create_app()`) to create a `Flask` app.
  - Configures CloudWatch-compatible logging (timestamp, logger name, level, message).
  - Endpoints:
    - `GET /health`:
      - Returns JSON `{"status": "ok", "service": "demo-backend"}`.
      - Logs the health check call.
    - `POST /echo`:
      - Verifies `Content-Type: application/json`.
      - Safely parses JSON and validates presence of a body.
      - Returns the same JSON payload under a `body` field, or a `400` error with a clear message on invalid input.
  - Error handlers:
    - `404` – returns a JSON `{ "error": "Endpoint not found" }`.
    - `405` – returns a JSON error when method is not allowed, including the disallowed HTTP method.
    - `500` – logs stack traces and returns a generic error message.
  - `before_request` and `after_request` hooks:
    - Log every incoming request and outgoing response for observability.
  - `if __name__ == '__main__'` block:
    - Starts the dev server on port 8000 for local runs.
  This file is the reference implementation for how a production-ready Flask app should be structured.

- `tests/__init__.py`  
  Empty package initializer for demo tests.

- `tests/unit/__init__.py`, `tests/integration/__init__.py`  
  Empty initializers so both test folders are Python packages.

- `tests/unit/test_health.py`  
  Unit test suite for `/health`:
  - Uses `pytest` fixtures and `Flask`’s test client.
  - Verifies:
    - HTTP 200 status for GET `/health`.
    - JSON content type.
    - Presence of `status` and `service` keys.
    - Expected values (`status == "ok"`, `service == "demo-backend"`).
    - That only GET is allowed; POST/PUT/DELETE return HTTP 405.

- `tests/integration/test_echo.py`  
  Integration tests for `/echo`:
  - Exercises full request/response cycle, including:
    - Valid JSON payload → 200, with payload echoed under `body`.
    - Nested and array JSON structures preserved correctly.
    - Empty JSON objects.
    - Missing/invalid `Content-Type` → 400.
    - Malformed JSON (syntax errors, partial payloads) → 400 with an error message.
    - Method checks: only POST allowed, all other methods return 405.
    - Larger payloads (e.g., 100 items) to check robustness.
    - Type preservation across JSON types (string, int, float, boolean, null, arrays, nested objects).
  These tests ensure the demo backend correctly demonstrates good API and error-handling practices.

---

## CI/CD Pipelines – `jenkins-pipeline-setting/`

Path: `jenkins-pipeline-setting/`

This directory contains the **Jenkinsfiles** that define CI and CD pipelines as code. Jenkins instances (local and EC2) read these directly from Git.

- `Jenkinsfile-CI`  
  Defines the **Continuous Integration** pipeline:
  - Parameter: `BACKEND_DIR` (either `demo-backend` or `backend`) to choose which backend to build and test.
  - Environment variables:
    - `IMAGE_NAME` – the Docker image base name (`aws-lab-flask-demo`).
    - `IMAGE_TAG` – build number, used as a unique tag.
    - `AWS_REGION` – region for ECR (us-east-1).
    - `TOOLS_PATH` – path adjustments so AWS CLI is available.
  - Stages:
    1. **Checkout** – pulls the source code.
    2. **Validate Jeffery Branch** – rejects builds for branches other than `Jeffery`. Ensures pipelines are focused on the lab branch.
    3. **Ensure AWS CLI** – installs AWS CLI v2 into the workspace if not present.
    4. **Setup Python Environment** – creates a virtualenv under the selected backend and upgrades `pip`.
    5. **Install Dependencies** – installs Python dependencies from `requirements.txt`.
    6. **Run Tests** – runs unit tests then integration tests with `pytest`, failing the pipeline on any error.
    7. **Build Docker Image** – builds a Lambda-compatible Docker image:
       - `--platform linux/amd64`.
       - Disables provenance and SBOM to satisfy Lambda constraints.
       - Tags the image both with the build number and `latest`.
    8. **Push Image to ECR** – logs into ECR, ensures the repository exists, tags the image with:
       - Specific build tag.
       - `latest` tag.
       - `jenkins-build` tag.
       Then pushes all tags and writes them to `push_vars.txt` for downstream use.
  This Jenkinsfile is the definitive CI process: if it is green, the Docker image is built, tested, and published to ECR.

- `Jenkinsfile-CD`  
  Defines the **Continuous Deployment** pipeline:
  - Parameters:
    - `BACKEND_DIR` – choose `demo-backend` or `backend`.
    - `IMAGE_TAG` – optional explicit ECR image tag (if omitted, the pipeline automatically discovers the latest tag).
  - Environment variables:
    - `IMAGE_NAME` – ECR repository name.
    - `AWS_REGION` – ECR region.
    - `SAM_CONFIG` – picks `samconfig-demo.toml` or `samconfig-prod.toml` based on `BACKEND_DIR`.
    - `STACK_NAME` – CloudFormation/SAM stack name (`flask-demo-backend` or `flask-prod-backend`).
    - `TOOLS_PATH` – ensures AWS and SAM CLIs are discoverable.
  - Stages:
    1. **Checkout** – fetches source.
    2. **Validate Jeffery Branch** – enforces that deployments only run on the `Jeffery` branch.
    3. **Ensure AWS CLI** – installs AWS CLI in the agent workspace if missing.
    4. **Ensure SAM CLI** – lazily installs SAM CLI into a venv under the workspace if missing.
    5. **Resolve AWS Account** – obtains `AWS_ACCOUNT_ID` via STS and builds the ECR registry URL.
    6. **Auto-detect or Validate Image Tag** – either:
       - Uses the parameter `IMAGE_TAG`, or
       - Queries ECR for the latest pushed image and selects its tag.
    7. **Deploy via SAM** – uses the selected tag, SAM template, and config to deploy the container image to Lambda/API Gateway.
    8. **Post-deploy Verification** – calls `/health` and `/echo` via the deployed API URL to ensure the deployment works.
  This file defines the **CD job** (`flask-cd`) and ensures that deployments are explicit, traceable, and validated.

---

## Automation Scripts – `scripts/`

Path: `scripts/`

Top-level directory for all automation shell scripts.

- `README.md`  
  High‑level catalog of scripts:
  - Explains the split between:
    - `scripts/local/` – safe, local-only helper scripts (never touch AWS).
    - `scripts/jenkins/` – shared CI/CD and Jenkins/ECR/SAM automation scripts.
  - Summarizes the purpose of each script and when you should run it.

### Local Helper Scripts – `scripts/local/`

Path: `scripts/local/`

These scripts are designed for **local-only smoke tests** and never talk to AWS.

- `test-local.sh`  
  Bash script to run the **pytest test suite locally**:
  - Arguments:
    - `--demo` – run tests for `demo-backend`.
    - `--prod` – run tests for `backend`.
  - Behavior:
    - Validates that exactly one of `--demo` or `--prod` is supplied.
    - Derives `BACKEND_DIR` and friendly `BACKEND_NAME`.
    - Checks prerequisites: Python 3, backend directory existence, and presence of `tests/`.
    - Creates or reuses a virtualenv in the backend directory.
    - Installs dependencies from `requirements.txt` on first run.
    - Runs `pytest tests/` with clear, colorized output and step-by-step headers.
  This script is meant to be run before commits and whenever Jenkins reports test failures.

- `build-local.sh`  
  Bash script to **build local Docker images** for either backend:
  - Arguments:
    - `--demo` – build an image from `demo-backend/`.
    - `--prod` – build an image from `backend/`.
  - Tags the image as `aws-lab-flask-demo:local`.
  - Mirrors the Docker build semantics used in the Jenkins CI job (platform, port, etc.), but without pushing to ECR.
  It allows developers to validate Dockerfile changes quickly without involving AWS.

### Jenkins / AWS Scripts – `scripts/jenkins/`

Path: `scripts/jenkins/`

These scripts are the **shared CI/CD toolkit** used both manually and from Jenkins stages.

- `.ecr-repo-uri`  
  Small helper file that may contain the fully-qualified ECR repository URI. Some scripts read this to avoid recomputing or re-prompting for the repo name/URI.

- `11-setup-ecr.sh`  
  Creates (or validates) the Amazon ECR repository used to store Docker images. Idempotent:
  - If repository exists, exits successfully.
  - If not, creates the repo with image scanning enabled.

- `20-ci-build-and-push.sh`  
  **Manual CI script** used primarily in Phase 3a (manual CI proof):
  - Arguments: `--demo` or `--prod` to choose backend.
  - Stages:
    1. Runs tests using pytest.
    2. Builds Docker image with Lambda-compatible settings (`--platform linux/amd64`).
    3. Logs in to ECR using AWS CLI / STS token.
    4. Tags the image with:
       - A specified `IMAGE_TAG` (default `manual-test`).
       - `latest`.
    5. Pushes the tags to ECR.
    6. Verifies that the image exists in ECR.
  - Provides rich instructional output explaining CI concepts like fail-fast behavior, tagging strategy, and ECR authentication.
  This is the CLI equivalent of the Jenkins CI pipeline and is used to prove the flow before automating.

- `30-cd-validate-sam.sh`  
  Validates the SAM template and environment:
  - Runs `sam validate`.
  - Checks that `LabRole` and other IAM/Learner Lab constraints are satisfied.
  - Ensures CloudFormation and SAM configuration are ready for deployment.

- `31-cd-deploy-sam.sh`  
  Performs **SAM-based deployment** using a supplied image tag:
  - Supports `--demo` or `--prod` to choose stack and SAM config file.
  - Accepts an `--image-tag` parameter; uses it to pass the appropriate `ImageTag` to `sam deploy`.
  - Deploys the container-based Lambda and API Gateway, mapping `/health` and `/echo`.

- `32-cd-verify-deployment.sh`  
  Post-deployment verifier:
  - Reads the deployed API URL (from `sam outputs` or script parameters).
  - Issues actual HTTP requests to `/health` and `/echo`.
  - Confirms that both endpoints behave correctly, with proper status codes and responses.

- `40-setup-jenkins-local.sh`  
  Boots a local Jenkins LTS instance in Docker:
  - Mounts the current repository into the Jenkins container.
  - Mounts the host Docker socket so Jenkins can build Docker images.
  - Prints initial admin password and Jenkins URL.
  Use this when you want to run `Jenkinsfile-CI` / `Jenkinsfile-CD` locally against your AWS credentials.

- `41-setup-jenkins-ec2.sh`  
  Provisions a **Jenkins EC2 instance** in AWS:
  - Default instance type `t3.medium` (override with `INSTANCE_TYPE`).
  - Installs Docker, Jenkins, SAM CLI, and other prerequisites.
  - Attaches `LabRole` as an instance profile.
  - Outputs connection information, admin password, and Blue Ocean URL.

- `42-configure-jenkins-jobs.sh`  
  Configures Jenkins jobs (`flask-ci` and `flask-cd`) via Jenkins CLI/API:
  - Works with either `--local` or `--ec2` modes.
  - Installs required plugins (Git, GitHub, workflow, AWS, Docker, Blue Ocean) with retries.
  - Creates pipelines from SCM that point at `jenkins-pipeline-setting/Jenkinsfile-CI` and `Jenkinsfile-CD`.
  This ensures Jenkins always uses the Jenkinsfiles stored in Git.

- `91-check-jenkins-status.sh`  
  Utility script to:
  - Check the health/status of the Jenkins EC2 instance.
  - Print Jenkins URLs and recent job status.
  - Tail or fetch Jenkins logs as needed.

- `93-start-jenkins-ec2.sh`  
  Starts the stopped Jenkins EC2 instance:
  - Resumes the EC2 instance using AWS CLI.
  - Prints the new public IP / DNS so webhooks and operators can reconnect.

- `94-stop-jenkins-ec2.sh`  
  Stops the Jenkins EC2 instance:
  - Shuts down the instance to control cost (only EBS storage charges remain).
  - Used at the end of work sessions.

- `99-cleanup-all.sh`  
  Cleanup script:
  - Deletes the CloudFormation/SAM stacks used by demo and/or production deployments.
  - Deletes the ECR repository and its images.
  - Typically prompts for confirmation before destructive actions.
  Used when tearing down the entire lab environment.

---

## Documentation – `docs/`

Path: `docs/`

Top-level documentation for users and maintainers.

- `overview.md`  
  Short, high‑level summary of:
  - The project’s learning goals and overall pipeline.
  - How `Jeffery` branch is wired for CI/CD.
  - Which directories matter for code (`backend/`, `demo-backend/`) and for infrastructure and scripts.
  - Prerequisites (Docker, Python, AWS CLI, SAM).

- `scripts.md`  
  Concise catalog of all scripts in `scripts/local/` and `scripts/jenkins/`, summarizing:
  - Each script’s purpose (test, build, deploy, verify, setup Jenkins, manage EC2, cleanup).
  - Typical usage scenarios.
  - Which scripts are safe for local use vs. which interact with AWS resources.

- `jenkins.md`  
  A playbook for using Jenkins in two modes:
  - **Local Jenkins via Docker** – how to:
    - Start Jenkins with `40-setup-jenkins-local.sh`.
    - Install required plugins.
    - Configure `flask-ci` and `flask-cd` jobs (manually or using `42-configure-jenkins-jobs.sh --local`).
  - **EC2 Jenkins** – how to:
    - Provision Jenkins on EC2 using `41-setup-jenkins-ec2.sh`.
    - Configure jobs via `42-configure-jenkins-jobs.sh --ec2`.
    - Wire GitHub webhooks to the EC2 instance.
    - Start/stop Jenkins EC2 to manage cost.

- `troubleshooting.md`  
  Troubleshooting cheatsheet:
  - Local environment issues (Python environment, Docker build failures, flaky tests).
  - Jenkins problems (checkout, permissions, AWS credentials).
  - AWS deployment issues (SAM role constraints, missing ECR images, 500 errors, stale stacks).
  Encourages reproducing problems with manual scripts before debugging in Jenkins.

- `VALIDATION.md`  
  End-to-end validation checklist:
  - Local service checks (`test-local.sh`, `build-local.sh`, `curl /health`).
  - Manual CI/CD script checks (`20-ci-build-and-push.sh`, `31-cd-deploy-sam.sh`, `32-cd-verify-deployment.sh`).
  - Local Jenkins checks (CI + CD jobs).
  - EC2 Jenkins and webhook checks.
  Meant to confirm that everything from local tests to AWS deployment still works after changes.

### Archived Documentation – `docs/archived/`

Path: `docs/archived/`

Older or high‑volume documentation preserved for reference.

- `AWS_CLI_REFERENCE.md`  
  Reference notes and cheat‑sheets for using AWS CLI commands relevant to this project (ECR, Lambda, CloudFormation, SAM, IAM). Not directly invoked by scripts.

- `clean-untaged-image-and-lifecycle-policy-for-automatic-cleanup.txt`  
  Notes about cleaning up untagged images in ECR and setting lifecycle policies, including example commands and rationale.

- `DEVELOPMENT_DIARY.md`  
  Detailed **development diary** for the project:
  - Chronological record of commits, decisions, and experiments.
  - Links to specific GitHub commits.
  - Descriptions of problems, their resolutions, and lessons learned.
  - Summaries of development phases and metrics (lines of code, test counts, build times).
  This file documents the full history and is invaluable for understanding the evolution of the project.

- `JENKINS_BLUE_OCEAN_SETUP.md`  
  Step‑by‑step guide for installing and configuring Jenkins Blue Ocean, including plugin installation, job setup, and best practices for visualizing pipelines.

- `phase3-troubleshooting.txt`  
  Focused troubleshooting notes from Phase 3 (manual CI/CD) covering issues around Docker builds, ECR authentication, SAM validation, and early Jenkins trials.

- `SCRIPT_GUIDE.md`  
  Older, more verbose script guide that predates `docs/scripts.md`. Provides deeper explanations and “why” behind each script’s behavior and options.

- `VALIDATION.md`  
  Archived validation document (full, verbose version) superseded by the shorter `docs/VALIDATION.md`. Contains more detailed step-by-step checks for each phase and script.

---

## Specifications – `specs/`

Path: `specs/`

Contains detailed design documents for the project.

### Feature Folder – `specs/001-aws-lab-flask-ci-cd-demo/`

Path: `specs/001-aws-lab-flask-ci-cd-demo/`

- `aws-lab-flask-spec.md`  
  **Feature specification** for the AWS Learner Lab Flask CI/CD demo:
  - User stories (local Flask app, Dockerization, local Jenkins, EC2 Jenkins).
  - Functional requirements (FR-001 to FR-008).
  - Entities (backend service, container image, CI pipeline run, AWS deployment).
  - Measurable success criteria (e.g., time to first `/health` response, CI pipeline duration).

- `aws-lab-flask-plan.md`  
  **Implementation plan** that maps the spec to concrete phases and tasks:
  - Project structure, directory layout, and code organization.
  - Phased execution (local Flask, Docker, manual CI/CD, Jenkins, EC2, automation, recovery).
  - Script numbering philosophy (grouped ranges for setup, CI, CD, utilities).
  - Detailed step-wise instructions for building and validating each phase.

- `aws-lab-flask-tasks.md`  
  **Task list** capturing work items per phase:
  - Checklists for project initialization, foundational setup, user story implementation, Dockerization, CI/CD scripting, and Jenkins integration.
  - IDs, parallelization hints, and references back to user stories.
  Used for tracking execution progress against the plan.

- `aws-lab-flask-agent.md`  
  Guidelines for AI agents (like this one) working in the repository:
  - Active technologies and constraints.
  - Project structure expectations.
  - Recommended local dev flow (Conda usage, commands to run).
  - How to use manual scripts before moving to Jenkins and EC2.

- `aws-lab-flask-checklist.md`  
  Comprehensive checklist (not fully shown above, but referenced in the diary and plan) tying together spec and plan items into a single, actionable verification list.

---

## Tests – `backend/tests/` and `demo-backend/tests/`

Although partially described under each backend, it is worth emphasizing:

- `backend/tests/`  
  Currently contains only `__init__.py` files (package scaffolding). Real tests for the production backend should be added here:
  - `backend/tests/unit/` – fine-grained tests for functions, routes, helpers.
  - `backend/tests/integration/` – end-to-end tests that exercise the app through HTTP-style flows.

- `demo-backend/tests/`  
  Fully populated with:
  - `unit/test_health.py` – unit tests for `/health`.
  - `integration/test_echo.py` – integration tests for `/echo` and error handling.
  These are the canonical examples for how to structure tests in the production backend.

---

## Summary of Roles

- **`demo-backend/`** – working reference implementation used to validate scripts, Docker, Jenkins, and SAM deployment. Do not modify when adding new features; treat it as the “baseline service”.
- **`backend/`** – your playground for building a real production service, with tests and Docker configuration mirroring the demo backend.
- **`aws/`** – Infrastructure as Code using SAM, defining how a containerized Flask app becomes a Lambda + API Gateway stack.
- **`jenkins-pipeline-setting/`** – Jenkins CI/CD logic, versioned as code and shared across local and EC2 Jenkins.
- **`scripts/`** – Unified toolkit for both manual and automated flows, from local tests to EC2 Jenkins management.
- **`docs/` & `specs/`** – Extensive documentation and design artifacts that explain **why** the project is structured this way and how to operate it safely.

Together, these files implement a complete learning environment for modern CI/CD with Flask, Docker, Jenkins, and AWS, with the demo backend serving as the proven baseline and the `backend/` directory ready for your production features.

