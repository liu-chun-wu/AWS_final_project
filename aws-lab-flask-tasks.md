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
