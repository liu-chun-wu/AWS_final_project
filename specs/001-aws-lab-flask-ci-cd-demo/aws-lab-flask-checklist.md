# Execution Checklist: AWS Learner Lab Flask CI/CD Demo

**Purpose**: Ensure each phase (local, Docker, Jenkins, AWS) of the demo is correctly implemented and verifiable.  
**Created**: 2025-11-21  
**Feature**: `specs/001-aws-lab-flask-ci-cd-demo/spec.md`

## Local Environment & Tooling

- [ ] CHK-L01 Python 3.11 installed and available in PATH (`python --version`).
- [ ] CHK-L02 Docker Engine installed and running (`docker ps` works).
- [ ] CHK-L03 Git client configured with access to GitHub repository.
- [ ] CHK-L04 Optional: `pytest` CLI installed (or available via virtualenv).

## Phase 1 – Local Flask Backend

- [ ] CHK-P1-01 Local Python environment created and activated for development:
  - Typically a **Conda environment** (e.g. `conda create -n aws-lab-flask python=3.11` + `conda activate aws-lab-flask`),  
    or alternatively a `python -m venv` virtualenv.

- [ ] CHK-P1-02 Dependencies installed from `backend/requirements.txt` without errors.
- [ ] CHK-P1-03 `flask run --port 8000` (or documented command) starts the server.
- [ ] CHK-P1-04 `GET http://localhost:8000/health` returns HTTP 200 and expected JSON.
- [ ] CHK-P1-05 `POST http://localhost:8000/echo` with JSON body returns echoed payload.
- [ ] CHK-P1-06 `pytest backend/tests` runs and all tests for US1 pass.

## Phase 2 – Dockerized Backend

- [ ] CHK-P2-01 `.dockerignore` exists and excludes venv, git, and build artifacts.
- [ ] CHK-P2-02 `docker build -t aws-lab-flask-demo:local backend/` completes successfully.
- [ ] CHK-P2-03 `docker run --rm -p 8000:8000 aws-lab-flask-demo:local` starts container.
- [ ] CHK-P2-04 `GET http://localhost:8000/health` works against the containerized app.
- [ ] CHK-P2-05 `POST http://localhost:8000/echo` works against the containerized app.
- [ ] CHK-P2-06 Container logs are readable and show request handling.

## Phase 3 – Local Jenkins CI (Optional)

- [ ] CHK-P3-01 Jenkins container is running and accessible at `http://localhost:8080/`.
- [ ] CHK-P3-02 Admin password collected from container and initial setup completed.
- [ ] CHK-P3-03 Jenkins has a job/pipeline pointing at the correct GitHub repository.
- [ ] CHK-P3-04 Pipeline script (Jenkinsfile) includes stages for checkout, tests, and Docker build.
- [ ] CHK-P3-05 Successful pipeline run visible with all stages green.
- [ ] CHK-P3-06 Pipeline fails as expected when a test is intentionally broken.

## Phase 3a – Manual CI Testing (Build & Push) - Critical Gate Part 1

- [ ] CHK-P3A-01 ECR repository created and accessible
- [ ] CHK-P3A-02 Local tests pass (pytest backend/tests -v)
- [ ] CHK-P3A-03 All 18 tests pass successfully
- [ ] CHK-P3A-04 Docker image builds locally without errors
- [ ] CHK-P3A-05 Docker image tagged correctly (manual-test)
- [ ] CHK-P3A-06 ECR login successful (aws ecr get-login-password)
- [ ] CHK-P3A-07 Image pushed to ECR successfully
- [ ] CHK-P3A-08 Image visible in ECR console with :manual-test tag
- [ ] CHK-P3A-09 Image also tagged with :latest

**Checkpoint**: CI operations (test/build/push) validated manually

---

## Phase 3b – Manual CD Testing (Deploy & Verify) - Critical Gate Part 2

- [ ] CHK-P3B-01 SAM template validates without errors (`sam validate`)
- [ ] CHK-P3B-02 LabRole exists in AWS account
- [ ] CHK-P3B-03 template.yaml updated to use LabRole (no IAM role creation)
- [ ] CHK-P3B-04 SAM build succeeds (`sam build --use-container`)
- [ ] CHK-P3B-05 SAM deploy succeeds manually (first deployment to demo-backend)
- [ ] CHK-P3B-06 CloudFormation stack created in correct region (us-east-1)
- [ ] CHK-P3B-07 Lambda function created and uses container image
- [ ] CHK-P3B-08 Lambda function has correct IAM role (LabRole)
- [ ] CHK-P3B-09 API Gateway endpoint accessible
- [ ] CHK-P3B-10 Health endpoint returns `{"status": "ok", "service": "demo-backend"}`
- [ ] CHK-P3B-11 Echo endpoint echoes request body correctly
- [ ] CHK-P3B-12 CloudWatch logs show Lambda invocations

**GATE**: All Phase 3a AND 3b checks must pass before proceeding to Phase 4

## Phase 4 – Jenkinsfile Preparation (Define Before Deploy)

- [ ] CHK-P4-01 Jenkinsfile-CI created in ci/ directory
- [ ] CHK-P4-02 Jenkinsfile-CI has all required stages (Checkout, Test, Build, Push)
- [ ] CHK-P4-03 Jenkinsfile-CI parameterized correctly (BACKEND_DIR, BRANCH_NAME)
- [ ] CHK-P4-04 Jenkinsfile-CI environment variables set (AWS_REGION, ECR_REPO)
- [ ] CHK-P4-05 Jenkinsfile-CD created in ci/ directory
- [ ] CHK-P4-06 Jenkinsfile-CD has all required stages (Validate, Deploy, Verify)
- [ ] CHK-P4-07 Jenkinsfile-CD parameterized correctly (IMAGE_TAG, BACKEND_TYPE)
- [ ] CHK-P4-08 Jenkinsfile-CD validates image exists before deployment
- [ ] CHK-P4-09 Both Jenkinsfiles committed to Git
- [ ] CHK-P4-10 Jenkinsfiles visible in GitHub repository

**Checkpoint**: Pipeline definitions complete and version-controlled

---

## Phase 5 – Jenkins EC2 Deployment (Deploy After Manual Validation)

- [ ] CHK-P5-01 EC2 provisioning script created (12-setup-jenkins-ec2.sh)
- [ ] CHK-P5-02 EC2 instance launched (t2.small, Amazon Linux 2023)
- [ ] CHK-P5-03 Security group created (SSH 22, Jenkins 8080, HTTPS 443)
- [ ] CHK-P5-04 Instance profile attached with LabRole
- [ ] CHK-P5-05 Jenkins installed and running on EC2
- [ ] CHK-P5-06 Docker installed and accessible to Jenkins user
- [ ] CHK-P5-07 AWS CLI configured with IAM role credentials
- [ ] CHK-P5-08 SAM CLI installed on EC2
- [ ] CHK-P5-09 Git installed on EC2
- [ ] CHK-P5-10 Jenkins accessible via http://<EC2-IP>:8080
- [ ] CHK-P5-11 Initial admin password retrieved
- [ ] CHK-P5-12 flask-ci job created in Jenkins (points to Jenkinsfile-CI)
- [ ] CHK-P5-13 flask-cd job created in Jenkins (points to Jenkinsfile-CD)
- [ ] CHK-P5-14 Jobs correctly configured to pull from Git repository

**Checkpoint**: Jenkins EC2 running with pre-defined pipelines

---

## Phase 6 – Jenkins Pipeline Testing (Test CI and CD Separately)

- [ ] CHK-P6-01 CI job manually triggered in Jenkins UI
- [ ] CHK-P6-02 CI job Stage 1 (Checkout) passes
- [ ] CHK-P6-03 CI job Stage 2 (Test) passes - 18/18 tests
- [ ] CHK-P6-04 CI job Stage 3 (Build) passes - Docker image created
- [ ] CHK-P6-05 CI job Stage 4 (Push) passes - Image in ECR with jeffery-<build> tag
- [ ] CHK-P6-06 CD job manually triggered with IMAGE_TAG parameter
- [ ] CHK-P6-07 CD job Stage 1 (Validate) passes - Image exists in ECR
- [ ] CHK-P6-08 CD job Stage 2 (Deploy) passes - SAM deploy succeeds
- [ ] CHK-P6-09 CD job Stage 3 (Verify) passes - Health check passes
- [ ] CHK-P6-10 CI job automatically triggers CD job on success
- [ ] CHK-P6-11 CD job receives correct IMAGE_TAG from CI job
- [ ] CHK-P6-12 CD job receives correct BACKEND_TYPE (demo-backend)

**Checkpoint**: Both CI and CD pipelines validated in Jenkins

---

## Phase 7 – End-to-End Automation (Webhook Integration)

- [ ] CHK-P7-01 GitHub webhook configured (points to EC2 Jenkins)
- [ ] CHK-P7-02 Webhook delivery test successful
- [ ] CHK-P7-03 Push to Jeffery branch triggers CI job automatically
- [ ] CHK-P7-04 CI job passes and triggers CD job
- [ ] CHK-P7-05 CD job deploys to demo-backend stack
- [ ] CHK-P7-06 Health endpoint accessible via API Gateway
- [ ] CHK-P7-07 Push to main branch triggers CI job
- [ ] CHK-P7-08 CD job deploys to prod-backend stack (not demo)
- [ ] CHK-P7-09 Both demo-backend and prod-backend stacks exist
- [ ] CHK-P7-10 Both API Gateway endpoints respond correctly

**Checkpoint**: Full automation validated (Push → Jenkins → AWS)

---

## Phase 8 – Recovery and Utility Scripts

- [ ] CHK-P8-01 Redeploy script created (`33-cd-redeploy-image.sh`)
- [ ] CHK-P8-02 Redeploy script works without rebuilding image
- [ ] CHK-P8-03 Rollback script created (`34-cd-rollback.sh`)
- [ ] CHK-P8-04 Rollback script lists recent ECR images
- [ ] CHK-P8-05 Rollback script deploys previous version successfully
- [ ] CHK-P8-06 CD logs viewer created (`92-view-cd-logs.sh`)
- [ ] CHK-P8-07 Jenkins status checker created (`91-check-jenkins-status.sh`)
- [ ] CHK-P8-08 EC2 stop script created (`94-stop-jenkins-ec2.sh`)
- [ ] CHK-P8-09 EC2 start script created (`93-start-jenkins-ec2.sh`)
- [ ] CHK-P8-10 Service restored to working state in <3 minutes using rollback

**Checkpoint**: Recovery tools available and tested

---

## Final Verification

- [ ] CHK-F01 All mandatory tasks in `tasks.md` marked as complete
- [ ] CHK-F02 README and quickstart guides updated and accurate
- [ ] CHK-F03 Demo workflow validated (local → Jenkins → AWS)
- [ ] CHK-F04 Resources cleanup plan documented (ECR, Lambda, API Gateway, EC2)
- [ ] CHK-F05 DEVELOPMENT_DIARY.md updated with Phase 8 entry
- [ ] CHK-F06 All spec files updated (plan.md, tasks.md, checklist.md)
- [ ] CHK-F07 CLAUDE.md reflects Phase 8 completion
- [ ] CHK-F08 No outdated script paths in documentation
- [ ] CHK-F09 All phases follow "Prove → Codify → Automate" philosophy
- [ ] CHK-F10 Full CI/CD automation working (Push → Jenkins → AWS)
