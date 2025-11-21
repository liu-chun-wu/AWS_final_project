# Execution Checklist: AWS Learner Lab Flask CI/CD Demo

**Purpose**: Ensure each phase (local, Docker, Jenkins, AWS) of the demo is correctly implemented and verifiable.  
**Created**: 2025-11-21  
**Feature**: `specs/001-aws-lab-flask-ci-cd-demo/spec.md`

## Local Environment & Tooling

- [ ] CHK-L01 Python 3.11 installed and available in PATH (`python --version`).
- [ ] CHK-L02 Docker Engine installed and running (`docker ps` works).
- [ ] CHK-L03 Git client configured with access to GitHub repository.
- [ ] CHK-L04 Optional: `pytest` CLI installed (or available via virtualenv).

## User Story 1 – Local Flask Backend

- [ ] CHK-US1-01 Local Python environment created and activated for development:
  - Typically a **Conda environment** (e.g. `conda create -n aws-lab-flask python=3.11` + `conda activate aws-lab-flask`),  
    or alternatively a `python -m venv` virtualenv.

- [ ] CHK-US1-02 Dependencies installed from `backend/requirements.txt` without errors.
- [ ] CHK-US1-03 `flask run --port 8000` (or documented command) starts the server.
- [ ] CHK-US1-04 `GET http://localhost:8000/health` returns HTTP 200 and expected JSON.
- [ ] CHK-US1-05 `POST http://localhost:8000/echo` with JSON body returns echoed payload.
- [ ] CHK-US1-06 `pytest backend/tests` runs and all tests for US1 pass.

## User Story 2 – Dockerized Backend

- [ ] CHK-US2-01 `.dockerignore` exists and excludes venv, git, and build artifacts.
- [ ] CHK-US2-02 `docker build -t aws-lab-flask-demo:local backend/` completes successfully.
- [ ] CHK-US2-03 `docker run --rm -p 8000:8000 aws-lab-flask-demo:local` starts container.
- [ ] CHK-US2-04 `GET http://localhost:8000/health` works against the containerized app.
- [ ] CHK-US2-05 `POST http://localhost:8000/echo` works against the containerized app.
- [ ] CHK-US2-06 Container logs are readable and show request handling.

## User Story 3 – Local Jenkins CI

- [ ] CHK-US3-01 Jenkins container is running and accessible at `http://localhost:8080/`.
- [ ] CHK-US3-02 Admin password collected from container and initial setup completed.
- [ ] CHK-US3-03 Jenkins has a job/pipeline pointing at the correct GitHub repository.
- [ ] CHK-US3-04 Pipeline script (Jenkinsfile) includes stages for checkout, tests, and Docker build.
- [ ] CHK-US3-05 Successful pipeline run visible with all stages green.
- [ ] CHK-US3-06 Pipeline fails as expected when a test is intentionally broken.

## User Story 4 – AWS CI/CD (Preview / Later Phase)

- [ ] CHK-US4-01 AWS Learner Lab account access confirmed; region decided (e.g., `us-east-1`).
- [ ] CHK-US4-02 Amazon ECR repository created and its URI documented.
- [ ] CHK-US4-03 AWS SAM template drafted for Lambda container + API Gateway.
- [ ] CHK-US4-04 IAM roles/policies drafted for Jenkins EC2 instance (ECR, CloudFormation, Lambda).
- [ ] CHK-US4-05 Manual test deployment (without Jenkins) of the container to Lambda succeeds.
- [ ] CHK-US4-06 API Gateway URL tested for `/health` and `/echo` endpoints.
- [ ] CHK-US4-07 CloudWatch Logs show entries for requests hitting Lambda function.

## Final Verification

- [ ] CHK-F01 All mandatory tasks in `tasks.md` marked as complete.
- [ ] CHK-F02 README and any quickstart guides are updated and accurate.
- [ ] CHK-F03 Demo script prepared (steps to show local, Docker, Jenkins, and AWS behavior).
- [ ] CHK-F04 Resources cleanup plan documented for AWS (delete ECR images, Lambda, API Gateway, EC2).
