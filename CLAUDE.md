# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project combines an **AI Generation Application** with a **CI/CD Pipeline** for automated deployment to AWS Lambda.

### Two Main Components:

1. **AI Generation Application** (`backend/`)
   - Flask REST API with AI-powered image and music generation
   - HuggingFace Stable Diffusion XL for images
   - Suno API for music (async)
   - AWS S3 for storage, DynamoDB for history

2. **CI/CD Pipeline**
   - Jenkins automation with GitHub webhooks
   - Docker containers for AWS Lambda
   - SAM for Infrastructure as Code

### Documentation Structure

| Document | Description |
|----------|-------------|
| [docs/QUICK_START.md](docs/QUICK_START.md) | 5-minute setup guide |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System diagrams |
| [docs/APPLICATION.md](docs/APPLICATION.md) | Backend API docs |
| [docs/CI_CD.md](docs/CI_CD.md) | Pipeline docs |
| [docs/TESTING.md](docs/TESTING.md) | Testing guide |
| [docs/SCRIPTS.md](docs/SCRIPTS.md) | Script reference |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Contribution guide |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |

**Philosophy:** Prove → Codify → Automate

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
./scripts/jenkins/40-setup-jenkins-local.sh  # Set up Jenkins container
./scripts/jenkins/42-configure-jenkins-jobs.sh --local --demo  # Auto-create local jobs
./scripts/local/test-local.sh     # Run tests locally
./scripts/local/build-local.sh    # Build Docker locally

# AWS CI/CD scripts (organized by purpose)

# Infrastructure Setup (one-time)
./scripts/jenkins/11-setup-ecr.sh              # Create ECR repository

# CI Operations (build/test/push)
./scripts/jenkins/20-ci-build-and-push.sh      # Build & push to ECR

# CD Operations (deploy/verify)
./scripts/jenkins/30-cd-validate-sam.sh        # Validate SAM template
./scripts/jenkins/31-cd-deploy-sam.sh          # Deploy to Lambda
./scripts/jenkins/32-cd-verify-deployment.sh   # Test endpoints

# Jenkins Setup (after manual validation)
./scripts/jenkins/41-setup-jenkins-ec2.sh --demo      # Launch Jenkins on EC2
./scripts/jenkins/42-configure-jenkins-jobs.sh --ec2 --demo # Create CI/CD jobs

# Utilities
./scripts/jenkins/91-check-jenkins-status.sh   # Check Jenkins EC2
./scripts/jenkins/93-start-jenkins-ec2.sh      # Start EC2 instance
./scripts/jenkins/94-stop-jenkins-ec2.sh       # Stop EC2 to save costs

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

## Project Structure

```
AWS_final_project/
├── backend/                     # Production AI backend
│   ├── src/app.py              # Flask application
│   ├── src/db.py               # DynamoDB helpers
│   └── tests/                  # 17 tests (12 unit + 5 integration)
├── demo-backend/               # CI/CD validation backend
├── jenkins-pipeline-setting/   # Jenkinsfiles (CI and CD)
├── aws/                        # SAM templates
├── scripts/
│   ├── local/                  # Local testing scripts
│   └── jenkins/                # CI/CD automation scripts
├── docs/                       # Main documentation
└── specs/                      # Design documents
```

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
