---
description: "Task list for AWS Learner Lab Flask CI/CD demo"
---

# Tasks: AWS Learner Lab Flask CI/CD Demo

**Input**: Design documents from `/specs/001-aws-lab-flask-ci-cd-demo/`  
**Prerequisites**: `plan.md` and `spec.md`

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

- Backend source lives under: `backend/src/`
- Tests live under: `backend/tests/`
- CI pipeline configuration lives under: `ci/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 [P] [ALL] Create base repository structure:

  - `backend/src/`
  - `backend/tests/unit/`
  - `backend/tests/integration/`
  - `ci/`
  - `specs/001-aws-lab-flask-ci-cd-demo/`

- [ ] T002 [P] [ALL] Initialize Git repository and set remote to GitHub.
- [ ] T003 [P] [ALL] Add `.gitignore` (Python, virtualenv, Docker, IDE files).
- [ ] T004 [P] [ALL] Add `.dockerignore` in `backend/` to exclude `__pycache__`, `.venv`, `.git`, etc.
- [ ] T005 [ALL] Create initial `README.md` with high-level goal and prerequisites.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before user stories can be implemented.

- [ ] T006 [ALL] Create `backend/requirements.txt` with at least:

  - `Flask`
  - `gunicorn`
  - `pytest`

- [ ] T007 [P] [ALL] Document local Python environment setup (Conda recommended):

  - Example with Conda:
    - `conda create -n aws-lab-flask python=3.11`
    - `conda activate aws-lab-flask`
    - `pip install -r backend/requirements.txt`

  - (Optional) Alternative with `python -m venv` if Conda is not available.

- [ ] T008 [P] [ALL] Install `pytest` and verify `pytest` command works in the project.
- [ ] T009 [ALL] Decide on application port (e.g., `8000`) and document it.

**Checkpoint**: Foundation ready — developer can create a Conda env (or virtualenv), install dependencies, and run tests locally in the repo.

---

## Phase 3: User Story 1 – Local Flask Backend (P1) 🎯 MVP

**Goal**: Run `GET /health` and `POST /echo` locally via Python without Docker.

**Independent Test**: `flask run` (or equivalent) works, and curl/Postman requests succeed.

### Tests for User Story 1

- [ ] T010 [P] [US1] Create `backend/tests/unit/test_health.py` using Flask test client to assert:

  - `/health` returns HTTP 200 and expected JSON.

- [ ] T011 [P] [US1] Create `backend/tests/integration/test_echo.py` to assert:

  - `POST /echo` with a JSON body returns the same body under `body`.

### Implementation for User Story 1

- [ ] T012 [US1] Implement Flask app in `backend/src/app.py`:

  - Initialize `Flask` app.
  - Implement `GET /health`.
  - Implement `POST /echo` with basic JSON validation and error handling.

- [ ] T013 [US1] Add app factory or entrypoint (`create_app` or global app) consistent with Flask best practices.
- [ ] T014 [US1] Add basic logging (request id, route, status code) to console.
- [ ] T015 [US1] Update `README.md` with local run instructions:

  - Virtualenv creation.
  - `pip install -r requirements.txt`.
  - `flask run --port 8000` or `python -m flask run`.

**Checkpoint**: Local Flask app is fully functional and testable independently.

---

## Phase 4: User Story 2 – Docker Image (P1)

**Goal**: Run the same backend inside a Docker container.

**Independent Test**: Only Docker installed; `docker build` and `docker run` reproduce US1 behavior.

### Tests for User Story 2

- [ ] T016 [P] [US2] Add integration test instructions (optional) for hitting containerized service using `requests` from host.

### Implementation for User Story 2

- [ ] T017 [US2] Create `backend/Dockerfile`:

  - Use Python slim image.
  - Install requirements.
  - Copy app source.
  - Set gunicorn entrypoint serving the Flask app on port 8000.

- [ ] T018 [P] [US2] Validate image size and iterate on `.dockerignore` as needed.
- [ ] T019 [US2] Update `README.md` with Docker usage:

  - `docker build -t aws-lab-flask-demo:local .`
  - `docker run --rm -p 8000:8000 aws-lab-flask-demo:local`

**Checkpoint**: All `/health` and `/echo` tests pass against containerized app.

---

## Phase 5: User Story 3 – Local Jenkins CI (P2)

**Goal**: Automate testing and image build via Jenkins running in Docker.

**Independent Test**: Jenkins pipeline can be run locally and produce a Docker image.

### Tests for User Story 3

- [ ] T020 [P] [US3] Add instructions for manually triggering pipeline and verifying stages.
- [ ] T021 [P] [US3] Confirm pipeline fails when a test is intentionally broken.

### Implementation for User Story 3

- [ ] T022 [US3] Run Jenkins in Docker with a named volume and Docker socket mount.
- [ ] T023 [US3] Create `ci/Jenkinsfile` with stages:

  - `Checkout`
  - `Setup Python & dependencies`
  - `Install dependencies`
  - `Run tests`
  - `Build Docker image`

- [ ] T024 [P] [US3] Configure Jenkins job pointing to GitHub repository and using `ci/Jenkinsfile`.
- [ ] T025 [US3] Document Jenkins setup steps (admin password, plugin installation, job creation) in `README.md` or separate doc.

**Checkpoint**: Jenkins pipeline is reproducible from a fresh Jenkins container.

---

## Phase 6: User Story 4 – AWS CI/CD (P3)

**Goal**: Reuse Jenkins pipeline on AWS EC2 to deploy Docker image via ECR + Lambda + API Gateway.

**Independent Test**: From Jenkins on EC2, trigger pipeline to build, push, and deploy.

### Tests for User Story 4

- [ ] T026 [P] [US4] Validate deployed `/health` endpoint via API Gateway URL.
- [ ] T027 [P] [US4] Verify CloudWatch logs include recent requests and responses.

### Implementation for User Story 4

- [ ] T028 [US4] Design and create SAM template for Lambda container + API Gateway.
- [ ] T029 [US4] Create Amazon ECR repository and document naming & tagging scheme.
- [ ] T030 [US4] Extend Jenkinsfile with AWS stages:

  - Login to ECR.
  - Tag & push image.
  - Run `sam build` and `sam deploy`.

- [ ] T031 [P] [US4] Configure IAM roles / policies for Jenkins EC2 to access ECR and deploy via CloudFormation/SAM.
- [ ] T032 [US4] Document full AWS deployment flow, including how to clean up resources.

**Checkpoint**: End-to-end CI/CD flow from Git push → Jenkins → ECR → Lambda → API Gateway verified at least once.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improve developer experience and robustness.

- [ ] T033 [P] [ALL] Add basic logging configuration suitable for CloudWatch (JSON or structured logs).
- [ ] T034 [P] [ALL] Add comments and docstrings in `backend/src/app.py`.
- [ ] T035 [P] [ALL] Refine documentation in `README.md` and `quickstart.md` (if present).
- [ ] T036 [P] [ALL] Optional: Add GitHub Actions workflow mirroring Jenkins pipeline for comparison.
- [ ] T037 [ALL] Run through the entire checklist and mark completed items.

---

## Dependencies & Execution Order

- Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1)  
- Phase 4 (US2) depends on US1 completion.  
- Phase 5 (US3) depends on US1 & US2 completion.  
- Phase 6 (US4) depends on Docker image and Jenkins pipeline being stable (US2 & US3).

Parallel opportunities:

- Tasks marked [P] in the same phase can be done concurrently.
- Once the foundational phase is complete, multiple user stories can be implemented by different team members.

---

## UPDATED ARCHITECTURE - Phase 8 Task Additions

### Phase 3a: Manual CI Testing - Build & Push (NEW - Critical Gate Part 1)

**Purpose**: Validate CI operations (test/build/push) work manually BEFORE automating via Jenkins

- [ ] T040 [P] Setup ECR repository
  - Run: `./scripts/aws-ci-cd/11-setup-ecr.sh`
  - Verify: ECR repository exists in us-east-1

- [ ] T041 Run tests locally
  - Run: `pytest backend/tests -v`
  - Verify: All 18 tests pass

- [ ] T042 Build and push first Docker image manually
  - Run: `./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo`
  - Verify: Image exists in ECR with `:manual-test` tag
  - Verify: Image also tagged with `:latest`

**Checkpoint**: CI operations (test/build/push) proven to work manually

---

### Phase 3b: Manual CD Testing - Deploy & Verify (NEW - Critical Gate Part 2)

**Purpose**: Validate CD operations (deploy/verify) work manually BEFORE automating via Jenkins

- [ ] T043 Create SAM validation script
  - Implement: `scripts/aws-ci-cd/30-cd-validate-sam.sh`
  - Checks:
    - SAM template syntax (`sam validate`)
    - ECR repository exists
    - At least one image in ECR
    - LabRole exists
    - SAM build works (`sam build --use-container`)

- [ ] T044 Validate SAM template
  - Run: `./scripts/aws-ci-cd/30-cd-validate-sam.sh --demo`
  - Verify: No errors, all checks pass

- [ ] T045 Fix IAM permissions in template.yaml
  - Add `Role: !Sub 'arn:aws:iam::${AWS::AccountId}:role/LabRole'` to Lambda function
  - Remove auto-created IAM role outputs
  - Verify: LabRole has necessary permissions

- [ ] T046 Deploy SAM manually first time
  - Run: `./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo --image-tag manual-test`
  - Verify: CloudFormation stack created, Lambda function deployed
  - Duration: ~3-5 minutes

- [ ] T047 Verify deployment works
  - Run: `./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo`
  - Verify: Health endpoint returns `{"status": "ok", "service": "demo-backend"}`
  - Verify: Echo endpoint echoes request body correctly

**GATE**: All Phase 3a AND 3b tasks must succeed before Phase 4!

**Checkpoint**: Both CI and CD operations proven to work manually

---

### Phase 4: Jenkinsfile Preparation (NEW - Define Before Deploy)

**Purpose**: Create complete Jenkins pipeline definitions locally, commit to Git BEFORE deploying Jenkins EC2

**Philosophy**: Define → Test → Deploy (not Deploy → Modify → Redeploy)

- [ ] T048 [P] Create Jenkinsfile-CI
  - Implement: `ci/Jenkinsfile-CI`
  - Stages:
    1. Checkout code
    2. Determine backend type (Jeffery branch=demo, main branch=prod)
    3. Setup Python environment (virtualenv)
    4. Run tests (pytest backend/tests -v)
    5. Build Docker image
    6. Login to ECR (aws ecr get-login-password)
    7. Tag image: `<ECR-URI>:<branch>-<build>` and `<ECR-URI>:latest`
    8. Push to ECR
  - Post-success: Trigger flask-cd job with IMAGE_TAG parameter
  - Environment variables: AWS_REGION, ECR_REPO, BACKEND_DIR

- [ ] T049 [P] Create Jenkinsfile-CD
  - Implement: `ci/Jenkinsfile-CD`
  - Parameters: IMAGE_TAG (required), BACKEND_TYPE (choice: demo-backend/prod-backend)
  - Stages:
    1. Validate image exists in ECR (`aws ecr describe-images`)
    2. Set SAM config file based on BACKEND_TYPE
    3. Build SAM (`sam build --use-container`)
    4. Deploy via SAM (`sam deploy --config-file <config> --parameter-overrides ImageTag=${IMAGE_TAG}`)
    5. Get API Gateway URL from CloudFormation outputs
    6. Verify health endpoint (`curl -f $API_URL/health`)
  - Environment variables: AWS_REGION, ECR_REPO, SAM_CONFIG

- [ ] T050 Commit Jenkinsfiles to Git
  - Add: `git add ci/Jenkinsfile-CI ci/Jenkinsfile-CD`
  - Commit: `git commit -m "feat: Add Jenkins CI/CD pipeline definitions"`
  - Push: `git push origin Jeffery`
  - Verify: Files visible in GitHub repository

**Checkpoint**: Jenkinsfile-CI and Jenkinsfile-CD committed to Git, ready for Jenkins to use

---

### Phase 5: Jenkins EC2 Deployment (Deploy AFTER Manual Validation)

**Purpose**: Provision EC2 Jenkins instance that pulls pre-defined pipelines from Git

- [ ] T051 [P] Create EC2 Jenkins provisioning script
  - Implement: `scripts/aws-ci-cd/12-setup-jenkins-ec2.sh`
  - Features:
    - Create security group (SSH 22, Jenkins 8080, HTTPS 443)
    - Create instance profile with LabRole
    - Launch t2.small with Amazon Linux 2023
    - User Data script installs: Java 17, Jenkins LTS, Docker, AWS CLI v2, SAM CLI, Git
    - Add jenkins user to docker group
    - Configure AWS CLI with instance role
    - Wait for instance ready and Jenkins service started
    - Output: Instance IP, Jenkins URL, initial admin password

- [ ] T052 Launch Jenkins EC2 instance
  - Run: `./scripts/aws-ci-cd/12-setup-jenkins-ec2.sh`
  - Verify: Instance running, Jenkins accessible at http://<EC2-IP>:8080
  - Duration: ~15 minutes (instance launch + software installation)
  - Note: Get initial admin password from script output

- [ ] T053 [P] Create Jenkins job configuration script
  - Implement: `scripts/aws-ci-cd/13-configure-jenkins-jobs.sh`
  - Creates two pipeline jobs via Jenkins CLI or REST API:
    - Job: `flask-ci` → Pipeline from SCM → Points to `ci/Jenkinsfile-CI`
    - Job: `flask-cd` → Pipeline from SCM → Points to `ci/Jenkinsfile-CD`
  - Configures GitHub webhook integration
  - Sets up GitHub credentials if needed

- [ ] T054 Configure Jenkins jobs
  - Run: `./scripts/aws-ci-cd/13-configure-jenkins-jobs.sh`
  - Verify: Both `flask-ci` and `flask-cd` jobs visible in Jenkins UI
  - Verify: Jobs correctly point to Jenkinsfiles in Git repository

**Checkpoint**: Jenkins EC2 running with CI and CD jobs configured (but not yet tested)

---

### Phase 6: Jenkins Pipeline Testing (Test CI and CD Separately)

**Purpose**: Validate Jenkins automates the SAME steps we proved work manually in Phase 3

- [ ] T060 Test CI pipeline in Jenkins (manual trigger)
  - In Jenkins UI: Navigate to `flask-ci` job
  - Click "Build with Parameters"
  - Set: BACKEND_DIR=demo-backend, BRANCH_NAME=jeffery
  - Click "Build" and watch Blue Ocean
  - Verify: Stage 1 (Checkout) ✓ Green
  - Verify: Stage 2 (Test) ✓ Green - 18/18 tests pass
  - Verify: Stage 3 (Build) ✓ Green - Docker image created
  - Verify: Stage 4 (Push) ✓ Green - Image in ECR: `jeffery-<build>` tag
  - Expected duration: 3-5 minutes
  - Success: Full pipeline green, image in ECR

- [ ] T061 Test CD pipeline in Jenkins (manual trigger)
  - Get latest image tag from ECR: `aws ecr describe-images ...`
  - In Jenkins UI: Navigate to `flask-cd` job
  - Click "Build with Parameters"
  - Set: IMAGE_TAG=jeffery-<build>, BACKEND_TYPE=demo-backend
  - Click "Build" and watch Blue Ocean
  - Verify: Stage 1 (Validate) ✓ Green - Image exists
  - Verify: Stage 2 (Deploy) ✓ Green - SAM deploy succeeds
  - Verify: Stage 3 (Verify) ✓ Green - Health check passes
  - Expected duration: 3-5 minutes
  - Success: Full pipeline green, API Gateway responds

- [ ] T062 Test CI → CD automatic trigger
  - Manually trigger `flask-ci` job
  - Verify: CI job completes successfully
  - Verify: CD job (`flask-cd`) automatically triggered
  - Verify: CD job receives correct IMAGE_TAG and BACKEND_TYPE
  - Verify: CD job deploys successfully
  - Success: Automatic chaining works

**Checkpoint**: Both CI and CD pipelines validated in Jenkins (proves automation works)

---

### Phase 7: End-to-End Automation (Webhook Integration)

**Purpose**: Configure GitHub webhooks for full CI/CD automation (Push → Jenkins → AWS)

- [ ] T070 Configure GitHub webhook
  - In GitHub repo: Settings → Webhooks → Add webhook
  - Payload URL: `http://<EC2-IP>:8080/github-webhook/`
  - Content type: application/json
  - Events: Push events
  - Branches: Jeffery, main
  - Test webhook delivery

- [ ] T071 Test Jeffery branch automation (demo-backend)
  - Make test commit: `echo "# Test" >> README.md`
  - Commit and push to Jeffery branch
  - Verify: Webhook triggers `flask-ci` job automatically
  - Verify: CI job success triggers `flask-cd` job (demo-backend)
  - Verify: demo-backend deployment succeeds
  - Test API: `curl <demo-API-URL>/health`
  - Success: Push to Jeffery → auto-deploy to demo-backend

- [ ] T072 Test main branch automation (prod-backend)
  - Merge Jeffery to main: `git checkout main && git merge Jeffery && git push`
  - Verify: Webhook triggers `flask-ci` job automatically
  - Verify: CI job success triggers `flask-cd` job (prod-backend)
  - Verify: prod-backend deployment succeeds
  - Test API: `curl <prod-API-URL>/health`
  - Success: Push to main → auto-deploy to prod-backend

**Checkpoint**: Full automation validated - Git push triggers complete CI/CD flow

---

### Phase 8: Recovery and Utility Scripts (Optional/Utility)

**Purpose**: Add rollback, redeploy, and monitoring capabilities for operations

- [ ] T080 [P] Create redeploy script
  - Implement: `scripts/aws-ci-cd/33-cd-redeploy-image.sh`
  - Purpose: Deploy existing ECR image without rebuilding
  - Usage: `./33-cd-redeploy-image.sh --demo --image-tag jeffery-42`
  - Use case: CD failed due to SAM config, image is fine

- [ ] T081 [P] Create rollback script
  - Implement: `scripts/aws-ci-cd/34-cd-rollback.sh`
  - Purpose: Deploy previous image version
  - Features: List recent ECR images, prompt to select, deploy chosen
  - Usage: `./34-cd-rollback.sh --demo`
  - Use case: New deployment has bugs, quick revert

- [ ] T082 [P] Create CD logs viewer
  - Implement: `scripts/aws-ci-cd/92-view-cd-logs.sh`
  - Shows:
    - CloudFormation stack events (last 20)
    - SAM deployment logs
    - Lambda function logs (tail)
  - Usage: `./92-view-cd-logs.sh --demo`
  - Use case: CD pipeline failed, need to troubleshoot

- [ ] T083 [P] Create Jenkins status checker
  - Implement: `scripts/aws-ci-cd/91-check-jenkins-status.sh`
  - Shows:
    - EC2 instance state
    - Jenkins service status (via SSH)
    - Jenkins URL and credentials
    - Recent builds
    - Resource usage (CPU, memory, disk)

- [ ] T084 [P] Create EC2 start/stop scripts
  - Implement: `scripts/aws-ci-cd/93-start-jenkins-ec2.sh`
  - Implement: `scripts/aws-ci-cd/94-stop-jenkins-ec2.sh`
  - Purpose: Cost management (stop EC2 when not in use)
  - Start: `./93-start-jenkins-ec2.sh`
  - Stop: `./94-stop-jenkins-ec2.sh`

- [ ] T085 Test rollback scenario
  - Deploy code with intentional bug
  - Run: `./34-cd-rollback.sh --demo`
  - Verify: Previous version deployed successfully
  - Success: Service restored to working state in <3 minutes

**Checkpoint**: Recovery and monitoring tools available and tested

---

## Updated Dependencies & Execution Order (Phase 8 Architecture)

**New Phase Order (Revised Implementation Strategy):**
1. Phase 1 (Local Flask)
2. Phase 2 (Docker)
3. **Phase 3a (Manual CI Testing)** - Build/Push locally without Jenkins
4. **Phase 3b (Manual CD Testing)** - Deploy/Verify locally without Jenkins
5. **Phase 4 (Jenkinsfile Preparation)** - Define pipelines as code, commit to Git
6. **Phase 5 (Jenkins EC2 Deployment)** - Deploy Jenkins with pre-defined pipelines
7. **Phase 6 (Jenkins Pipeline Testing)** - Test CI and CD separately in Jenkins
8. **Phase 7 (End-to-End Automation)** - Configure webhooks, full automation
9. **Phase 8 (Recovery Scripts)** - Add rollback, monitoring (optional/utility)

**Critical Gates:**
- **Phase 3a → Phase 3b**: CI operations (build/push) must work before CD operations
- **Phase 3b → Phase 4**: Manual CD must succeed before writing Jenkinsfiles
- **Phase 4 → Phase 5**: Jenkinsfiles must be committed to Git before Jenkins EC2 launch
- **Phase 5 → Phase 6**: Jenkins EC2 must be running before testing pipelines
- **Phase 6 → Phase 7**: Both CI and CD pipelines must pass before webhook automation

**Key Philosophy:**
- **Prove → Codify → Automate** (not Deploy → Debug → Modify)
- Test each step manually first, then automate proven steps
- Jenkins deployment happens LATE (after proving manual path works)

**Parallel Opportunities:**
- T040, T041, T042 (ECR setup, build, push) can run in parallel
- T043, T044, T045 (SAM validation scripts) can run in parallel
- T048, T049 (Jenkinsfile creation) can run in parallel
- T051, T053 (EC2 provisioning script, job config script) can run in parallel
- T080-T085 (recovery scripts) can run in parallel

**Sequential Requirements:**
- T041 (run tests) must succeed before T042 (build/push)
- T042 (build/push) must succeed before T043 (SAM validation)
- T046 (deploy SAM) must succeed before T047 (verify deployment)
- T047 (verify deployment) must succeed before T048 (write Jenkinsfile-CI)
- T050 (commit Jenkinsfiles) must complete before T052 (launch EC2)
- T052 (launch EC2) must complete before T054 (configure jobs)
- T054 (configure jobs) must complete before T060 (test CI in Jenkins)
- T062 (test CI→CD trigger) must succeed before T070 (webhook config)

**Why This Order is Better:**
1. **Lower Risk**: Validate each step manually before automation
2. **Faster Iteration**: Debug locally (terminal) vs remotely (Jenkins logs)
3. **One-Time Deploy**: Jenkins EC2 deployed once with complete configuration
4. **Higher Confidence**: Jenkins automates proven steps (we already know they work!)
5. **Better IaC**: Jenkinsfiles are version-controlled code, not Jenkins UI configuration

