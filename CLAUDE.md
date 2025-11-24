# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **CI/CD demonstration project** showcasing a complete development pipeline from local Flask development to AWS cloud deployment.

**Current Status:** Phase 8 COMPLETE - Refined CI/CD implementation order:
- ✅ Phase 1: Local Flask REST API
- ✅ Phase 2: Docker containerization
- ✅ Phase 3a: Manual CI testing (build/push WITHOUT Jenkins)
- ✅ Phase 3b: Manual CD testing (deploy/verify WITHOUT Jenkins)
- ✅ Phase 4: Jenkinsfile preparation (define pipelines as Git-committed code)
- ✅ Phase 5: Jenkins EC2 deployment (one-time, pulls configs from Git)
- ✅ Phase 6: Jenkins pipeline testing (CI and CD validated separately)
- ✅ Phase 7: End-to-end automation (webhooks → Jenkins → AWS)
- ✅ Phase 8: Implementation order refinement
  - Philosophy: **Prove → Codify → Automate**
  - Manual testing BEFORE Jenkins deployment
  - One-time EC2 deployment (no redeploy cycles)
  - Higher confidence, lower risk, faster debugging

## Common Development Commands

### Local Development

```bash
# Setup Python environment (Conda recommended for this project)
conda create -n aws-lab-flask python=3.11 -y
conda activate aws-lab-flask
cd backend
pip install -r requirements.txt

# Run Flask application locally
export FLASK_APP=src.app
flask run --port 8000

# Run tests
pytest backend/tests                 # All tests
pytest backend/tests/unit/           # Unit tests only
pytest backend/tests/integration/    # Integration tests only
```

### Docker Commands

```bash
# Build Docker image
docker build -t aws-lab-flask-demo:local backend/

# Run containerized application
docker run --rm -p 8000:8000 aws-lab-flask-demo:local

# Verify container is running
docker ps
```

### Local Jenkins CI/CD

```bash
# Start Jenkins in Docker for local pipeline testing
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec <jenkins-container> cat /var/jenkins_home/secrets/initialAdminPassword
```

### AWS Deployment (Phase 7 - Production Ready)

```bash
# Local CI-only scripts (testing without AWS)
./scripts/local-ci-only/setup-jenkins.sh  # Set up Jenkins container
./scripts/local-ci-only/test-local.sh     # Run tests locally
./scripts/local-ci-only/build-local.sh    # Build Docker locally

# AWS CI/CD scripts (organized by purpose)

# 10-19: Infrastructure Setup (one-time)
./scripts/aws-ci-cd/10-check-prerequisites.sh    # Verify AWS environment
./scripts/aws-ci-cd/11-setup-ecr.sh              # Create ECR repository

# 20-29: CI Operations (build/test/push)
./scripts/aws-ci-cd/20-ci-build-and-push.sh      # Build & push to ECR
./scripts/aws-ci-cd/21-ci-validate-image.sh      # Verify image exists

# 30-39: CD Operations (deploy/verify/rollback)
./scripts/aws-ci-cd/30-cd-validate-sam.sh        # Validate SAM template
./scripts/aws-ci-cd/31-cd-deploy-sam.sh          # Deploy to Lambda
./scripts/aws-ci-cd/32-cd-verify-deployment.sh   # Test endpoints
./scripts/aws-ci-cd/33-cd-redeploy-image.sh      # Redeploy existing image
./scripts/aws-ci-cd/34-cd-rollback.sh            # Rollback to previous

# 40-49: Jenkins Setup (after manual validation)
./scripts/aws-ci-cd/40-setup-jenkins-ec2.sh      # Launch Jenkins on EC2
./scripts/aws-ci-cd/41-configure-jenkins-jobs.sh # Create CI/CD jobs

# 90-99: Utilities and Cleanup
./scripts/aws-ci-cd/90-check-aws-status.sh       # Check AWS resources
./scripts/aws-ci-cd/91-check-jenkins-status.sh   # Check Jenkins EC2
./scripts/aws-ci-cd/92-view-cd-logs.sh           # View deployment logs
./scripts/aws-ci-cd/93-start-jenkins-ec2.sh      # Start EC2 instance
./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh       # Stop EC2 to save costs
./scripts/aws-ci-cd/99-cleanup-all.sh            # Delete all resources

# Manual AWS commands (if not using scripts)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr-uri>
docker tag aws-lab-flask-demo:local <ecr-uri>:latest
docker push <ecr-uri>:latest
sam build && sam deploy --guided
aws logs tail /aws/lambda/<function-name> --follow
```

## Architecture

### Progressive 6-Phase Design

The architecture builds progressively, with each phase adding capability:

1. **Phase 1 - Local Flask**: Stateless REST API with `/health` and `/echo` endpoints
2. **Phase 2 - Containerization**: Docker with gunicorn WSGI server
3. **Phase 3 - Manual SAM Validation**: Prove deployment works before automation (CRITICAL GATE)
4. **Phase 4 - Jenkins on EC2**: Production-ready Jenkins with separate CI and CD jobs
5. **Phase 5 - Full Automation**: GitHub push → CI job → CD job → Lambda deployed
6. **Phase 6-7 - Refinement**: Script organization, rollback capability, cost management

### Key Architectural Patterns

- **Stateless Service**: No database, no sessions - pure request/response pattern
- **Container-First Design**: Single Docker image works identically in local and AWS Lambda environments
- **Infrastructure as Code**: Jenkinsfile for CI/CD, SAM templates for AWS resources
- **Lambda Container Model**: Uses Lambda's container runtime (not traditional zip deployment)

### API Contract

- `GET /health` → `{"status": "ok", "service": "demo-backend"}`
- `POST /echo` → `{"body": <request-body>}` (echoes back the JSON request body)
- All responses are JSON
- Standard port: 8000 (local, Docker, and Lambda via API Gateway)

### CI/CD Pipeline Stages

1. **Checkout**: Clone repository from Git
2. **Setup**: Install Python dependencies
3. **Test**: Run pytest suite (pipeline fails if tests fail)
4. **Build**: Create Docker image
5. **Deploy** (AWS only): Push to ECR and deploy via SAM

## Technology Stack

- **Python 3.11** (required - not 3.12+ due to AWS Lambda compatibility constraints)
- **Flask 3.x** for REST API
- **Gunicorn** for production WSGI serving (not Flask dev server)
- **Pytest** for unit and integration testing
- **Docker** for containerization
- **Jenkins** for CI/CD orchestration
- **AWS SAM CLI** for infrastructure deployment
- **AWS Services**: ECR, Lambda (container), API Gateway, CloudWatch

## Project Structure (Planned)

```
aws-lab-flask-ci-cd/
├── backend/
│   ├── src/
│   │   └── app.py              # Flask app with endpoints & CloudWatch-compatible logging
│   ├── tests/
│   │   ├── unit/               # Flask test client unit tests
│   │   └── integration/        # Full request/response integration tests
│   ├── requirements.txt        # Flask, gunicorn, pytest
│   ├── Dockerfile              # Multi-stage build for Lambda container compatibility
│   └── .dockerignore
├── ci/
│   ├── Jenkinsfile-CI          # CI pipeline (test, build, push)
│   └── Jenkinsfile-CD          # CD pipeline (deploy, verify)
├── specs/                      # Comprehensive planning documentation (completed)
├── .gitignore
└── README.md
```

## Implementation Status

**CURRENT STATE: PHASE 7 COMPLETE - PRODUCTION READY**

All 7 phases complete with full CI/CD automation, Jenkins EC2 deployment, separated CI/CD pipelines, and comprehensive scripts.

### Implementation Order (Phase 8 Refinement)

**Philosophy: Prove → Codify → Automate**

When implementing this project, follow this sequence:

1. Create directory structure (backend/src/, backend/tests/, ci/)
2. Add .gitignore and .dockerignore files
3. Create requirements.txt with Flask, gunicorn, pytest
4. Implement Flask app in backend/src/app.py
5. Write unit tests for /health endpoint
6. Write integration tests for /echo endpoint
7. Create Dockerfile with Lambda-compatible runtime
8. Create SAM template for AWS deployment
9. **Phase 3a: Test CI manually** - Run pytest, docker build, docker push to ECR (WITHOUT Jenkins)
10. **Phase 3b: Test CD manually** - Run sam validate, sam deploy, verify endpoints (WITHOUT Jenkins)
11. **Phase 4: Create Jenkinsfile-CI locally** - Mirror Phase 3a manual steps
12. **Phase 4: Create Jenkinsfile-CD locally** - Mirror Phase 3b manual steps
13. **Phase 4: Commit Jenkinsfiles to Git** - Version control pipeline definitions
14. **Phase 5: Deploy Jenkins on EC2** - Provision with pre-defined pipelines from Git
15. **Phase 6: Test CI pipeline in Jenkins** - Verify automation of Phase 3a
16. **Phase 6: Test CD pipeline in Jenkins** - Verify automation of Phase 3b
17. **Phase 7: Configure GitHub webhooks** - Enable full automation (Push → Jenkins → AWS)
18. **Phase 8: Test rollback scenario** - Validate recovery capabilities

**Key Insight:** Test each step manually (Steps 9-10) BEFORE automating with Jenkins (Steps 14-16)

## Important Constraints

### AWS Learner Lab Limitations
- Limited time sessions (4-6 hours typical)
- Restricted service access (only ECR, Lambda, API Gateway, CloudWatch)
- Temporary credentials (must re-authenticate each session)
- Region restricted to us-east-1
- Must clean up resources to avoid quota issues

### Design Requirements
- **Python 3.11 only** (Lambda runtime compatibility)
- **No database** (keep stateless for simplicity)
- **Tests must pass** before Docker build in CI pipeline
- **Container must be Lambda-compatible** (AWS base image or compatible runtime)
- **Total pipeline execution under 10 minutes** (success criteria)

## Testing Strategy

- **Unit Tests**: Use Flask test client to test individual endpoints in isolation
- **Integration Tests**: Full HTTP request/response cycle testing
- **CI Pipeline**: Tests must pass before image build (fail fast principle)
- **Validation Testing**: Intentionally break tests to verify pipeline properly fails

## Learning Objectives Context

This is a **student project** focused on understanding:
- Complete CI/CD pipeline implementation
- Docker containerization and best practices
- AWS serverless deployment patterns
- Infrastructure as Code with SAM
- DevOps automation with Jenkins

The application logic is intentionally simple - the focus is on the pipeline, not application complexity.
