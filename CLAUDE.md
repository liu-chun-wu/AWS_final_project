# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **CI/CD demonstration project** showcasing a complete development pipeline from local Flask development to AWS cloud deployment.

**Current Status:** Phase 6 COMPLETE - Full CI/CD automation implemented with:
- ✅ Phases 1-5: Local Flask app, Docker, Jenkins, Webhook automation
- ✅ Phase 6: AWS deployment automation with comprehensive scripts
- ✅ Branch-based CI/CD: Jeffery (CI only) + main (full CI/CD)

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

### AWS Deployment (Phase 6 - Automated)

```bash
# Local helper scripts (CI testing)
./scripts/local/setup-jenkins.sh          # Set up Jenkins container
./scripts/local/test-local.sh             # Run tests locally
./scripts/local/build-local.sh            # Build Docker locally

# AWS deployment scripts (CD)
./scripts/aws/01-check-prerequisites.sh   # Verify AWS environment
./scripts/aws/02-setup-ecr.sh             # Create ECR repository (one-time)
./scripts/aws/03-build-and-push.sh        # Build & push to ECR
./scripts/aws/04-deploy-sam.sh            # Deploy to Lambda + API Gateway
./scripts/aws/05-verify-deployment.sh     # Test & validate deployment
./scripts/aws/check-aws-status.sh         # Check resource status
./scripts/aws/99-cleanup-all.sh           # Delete all AWS resources

# Manual AWS commands (if not using scripts)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr-uri>
docker tag aws-lab-flask-demo:local <ecr-uri>:latest
docker push <ecr-uri>:latest
sam build && sam deploy --guided
aws logs tail /aws/lambda/<function-name> --follow
```

## Architecture

### Progressive 4-Phase Design

The architecture builds progressively, with each phase adding capability without breaking previous phases:

1. **Phase 1 - Local Flask**: Stateless REST API with `/health` and `/echo` endpoints
2. **Phase 2 - Containerization**: Same app in Docker using gunicorn WSGI server
3. **Phase 3 - Local CI/CD**: Jenkins pipeline with automated testing and image building
4. **Phase 4 - AWS Integration**: ECR registry + Lambda container + API Gateway + CloudWatch

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
│   └── Jenkinsfile             # Pipeline-as-code with all 5 stages
├── specs/                      # Comprehensive planning documentation (completed)
├── .gitignore
└── README.md
```

## Implementation Status

**CURRENT STATE: PRE-IMPLEMENTATION**

All planning documentation is complete (spec.md, plan.md, tasks.md, checklist.md, agent.md). No source code has been implemented yet.

### Implementation Order

When implementing this project, follow this sequence:

1. Create directory structure (backend/src/, backend/tests/, ci/)
2. Add .gitignore and .dockerignore files
3. Create requirements.txt with Flask, gunicorn, pytest
4. Implement Flask app in backend/src/app.py
5. Write unit tests for /health endpoint
6. Write integration tests for /echo endpoint
7. Create Dockerfile with Lambda-compatible runtime
8. Implement Jenkinsfile with all pipeline stages
9. Create SAM template for AWS deployment
10. Update README with actual setup instructions

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
