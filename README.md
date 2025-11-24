# AWS Learner Lab Flask CI/CD Demo

**Phase 8 IN PROGRESS** - Manual validation → local Jenkins → EC2 Jenkins, using one shared CI/CD toolkit

A comprehensive demonstration project showing how to take a Flask REST API from local development to AWS Lambda via Docker, Jenkins, and SAM. Every stage is proven manually first, then automated in local Jenkins, then handed off to Jenkins on EC2.

## Project Overview

This project demonstrates a **production-ready CI/CD pipeline** with:

- **Local Development**: Flask REST API with automated testing
- **Containerization**: Docker packaging for AWS Lambda compatibility
- **Automated CI/CD**: Jenkins pipeline with GitHub webhook triggers
- **Branch Strategy**: Development (CI only) vs Production (full CI/CD)
- **AWS Automation**: Complete deployment via scripts and SAM
- **Dual Backend Support**: Demo validation app + production service structure

## Key Features

- ✅ **Automated Testing**: 18 pytest tests (unit + integration)
- ✅ **Branch-Based Deployment**: Jeffery (CI only) vs main (CI + CD)
- ✅ **GitHub Webhooks**: Automatic builds on every push
- ✅ **AWS Automation**: 11 scripts for complete AWS lifecycle management
- ✅ **Container-Based Lambda**: Docker images deployed to AWS Lambda
- ✅ **Infrastructure as Code**: SAM templates with multi-profile support
- ✅ **Dual Backend Structure**: Separate demo and production deployments

## Architecture

### Progressive Implementation (8 Phases)

**Philosophy:** Prove → Codify → Automate *(test manually BEFORE automating with Jenkins)*

1. ✅ **Phase 1** - Local Flask REST API
2. ✅ **Phase 2** - Docker containerization
3. ✅ **Phase 3a** - Manual CI scripts (pytest + Docker build + ECR push)
4. ✅ **Phase 3b** - Manual CD scripts (SAM deploy + API verification)
5. ✅ **Phase 4** - Jenkinsfiles + local Jenkins automation (dockerized Jenkins using developer AWS creds)
6. ✅ **Phase 5** - Jenkins EC2 provisioning (pull Jenkinsfiles from Git)
7. ✅ **Phase 6** - Jenkins pipeline testing on EC2 (mirror local Jenkins)
8. ✅ **Phase 7** - End-to-end automation (GitHub webhook → Jenkins → AWS)
9. ✅ **Phase 8** - Recovery tooling + workflow refinement *(current focus)*

### Phase 8 Highlights

- **Prove → Codify → Automate**: Terminal scripts → local Jenkins → EC2 Jenkins
- **Single Toolkit**: `scripts/local/` for developer validation, `scripts/jenkins/` for shared CI/CD + EC2 helpers
- **Git-Committed Pipelines**: Jenkinsfile-CI and Jenkinsfile-CD are the only source of truth
- **Separate CI/CD**: Individual jobs make rollback, redeploy, and troubleshooting straightforward
- **Cost Management**: Start/stop EC2 scripts and local Jenkins workflows keep AWS spend low

### Branch-Based CI/CD Strategy

| Branch | Pipeline Mode | Stages | Deployment | Use Case |
|--------|--------------|--------|------------|----------|
| **Jeffery** | Auto CI + manual CD | **CI**:<br>1) Checkout<br>2) Branch check<br>3) Setup virtualenv<br>4) Install deps<br>5) Run tests<br>6) Build Docker<br>**CD**:<br>1) Validate image<br>2) Deploy via SAM<br>3) Verify endpoints | Deploy via `flask-cd` with `demo-backend` parameters for production | Daily development & testing |
| **main** | same as Jeffery branch | same as Jeffery branch| Deploy via `flask-cd` with `backend` parameters for production | Production releases |

GitHub webhooks trigger CI for both branches. When you’re ready to deploy a specific image (Jeffery test or main production), capture its IMAGE_TAG from the CI job and run `flask-cd` manually (local or EC2 Jenkins) with the desired `BACKEND_DIR`.

**Jeffery Branch (Development):**

- Checkout → Setup → Install → Test → Build → Done
- Fast feedback without AWS costs
- Safe for experimentation

**Main Branch (Production):**

- Same CI stages run automatically when you push to main
- After CI succeeds, run Jenkins `flask-cd` with `BACKEND_DIR=backend` and the approved IMAGE_TAG
- Promotes the chosen image to AWS Lambda/API Gateway

See [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) for complete workflow documentation.

## Project Structure

```
aws-lab-flask-ci-cd/
├── demo-backend/           # Flask demo for CI/CD validation
│   ├── src/
│   │   └── app.py         # /health and /echo endpoints
│   ├── tests/
│   │   ├── unit/          # 18 comprehensive tests
│   │   └── integration/
│   ├── requirements.txt
│   └── Dockerfile
│
├── backend/                # Production service (for collaborators)
│   ├── src/               # Your production code here
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── ci/
│   ├── Jenkinsfile-CI     # CI pipeline (test, build, push)
│   └── Jenkinsfile-CD     # CD pipeline (deploy, verify)
│
├── aws/
│   ├── template.yaml      # SAM infrastructure template
│   ├── samconfig-demo.toml   # Demo deployment config
│   └── samconfig-prod.toml   # Production deployment config
│
├── scripts/
│   ├── local/             # Manual CI helpers (pytest + Docker)
│   │   ├── test-local.sh
│   │   └── build-local.sh
│   └── jenkins/           # Shared CI/CD scripts + Jenkins tooling
│       ├── 40-setup-jenkins-local.sh
│       ├── 11-setup-ecr.sh
│       ├── 20-ci-build-and-push.sh
│       ├── 30-cd-validate-sam.sh
│       ├── 31-cd-deploy-sam.sh
│       ├── 32-cd-verify-deployment.sh
│       ├── 41-setup-jenkins-ec2.sh
│       ├── 42-configure-jenkins-jobs.sh
│       ├── 91-check-jenkins-status.sh
│       ├── 93-start-jenkins-ec2.sh
│       └── 94-stop-jenkins-ec2.sh
│
├── specs/                 # Complete planning documentation
├── BRANCH_STRATEGY.md     # Detailed workflow guide
├── COLLABORATION.md       # Team collaboration guide
├── docs/archived/         # Full development diary + legacy notes
└── README.md             # This file
```

## Documentation Set

- `docs/overview.md` – project purpose, phase order, branch strategy.
- `docs/scripts.md` – one-page catalog for every helper script.
- `docs/jenkins.md` – how to run Jenkins locally and on EC2.
- `docs/troubleshooting.md` – quick fixes for local, Jenkins, and AWS failures.
- `docs/validation.md` – condensed checklist to verify CI/CD end-to-end.

## Prerequisites

- **Python 3.11** (AWS Lambda compatibility requirement)
- **Docker** Desktop running
- **Git** for version control
- **AWS Account** (AWS Learner Lab recommended)
- **AWS CLI** configured with credentials
- **AWS SAM CLI** for infrastructure deployment

## Quick Start

### Step 1 – Prove CI/CD with local scripts

```bash
# Run pytest + Docker build without Jenkins
./scripts/local/test-local.sh --demo
./scripts/local/build-local.sh --demo

# Deploy manually via SAM (uses scripts/jenkins)
./scripts/jenkins/20-ci-build-and-push.sh --demo
./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag manual-test
```

### Step 2 – Automate with local Jenkins

```bash
# Start Jenkins in Docker (mounts repo + Docker socket)
./scripts/jenkins/40-setup-jenkins-local.sh

# Access Jenkins at http://localhost:8080 and run:
#   - flask-ci (tests + Docker build + ECR push)
#   - flask-cd (SAM deploy + API verification)
# Or auto-create the jobs:
./scripts/jenkins/42-configure-jenkins-jobs.sh --local --demo
```

### Step 3 – Move automation to EC2 Jenkins

```bash
# Provision Jenkins EC2 host
./scripts/jenkins/41-setup-jenkins-ec2.sh --demo

# Configure jobs straight from Git
./scripts/jenkins/42-configure-jenkins-jobs.sh --ec2 --demo
```

Once EC2 Jenkins mirrors the successful local runs, enable the GitHub webhook so pushes to Jeffery automatically trigger the CI job. When you are ready to deploy, run the `flask-cd` job manually (local or EC2) with the desired image tag.

#### Phase 3: Manual SAM Validation (Critical Gate)

```bash
# IMPORTANT: Validate SAM works manually before Jenkins automation

# 3. Build and push first Docker image
./scripts/jenkins/20-ci-build-and-push.sh --demo

# 4. Validate SAM template
./scripts/jenkins/30-cd-validate-sam.sh --demo

# 5. Deploy to Lambda manually (first time)
./scripts/jenkins/31-cd-deploy-sam.sh --demo

# 6. Verify deployment works
./scripts/jenkins/32-cd-verify-deployment.sh --demo

# ✅ If all succeed, proceed to Phase 4
```

#### Phase 4: Jenkins on EC2 (Automation)

```bash
# 7. Launch Jenkins on EC2 instance
./scripts/jenkins/41-setup-jenkins-ec2.sh --demo

# 8. Configure CI and CD Jenkins jobs
./scripts/jenkins/42-configure-jenkins-jobs.sh --ec2 --demo

# ✅ GitHub pushes now trigger CI automatically; run `flask-cd` manually when ready to deploy
```

#### Daily Operations (After Setup)

```bash
# Normal workflow: Just push to GitHub
git push origin Jeffery  # Triggers CI → CD to demo-backend

# Check AWS resources status
./scripts/jenkins/32-cd-verify-deployment.sh --demo

# Check Jenkins EC2 status
./scripts/jenkins/91-check-jenkins-status.sh --demo

# View deployment logs (if CD fails)
./scripts/jenkins/92-view-cd-logs.sh --demo
```

#### Recovery Operations

```bash
# Redeploy a specific image tag (for rollback or hotfix)
./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag jeffery-42

# Manual deployment (if Jenkins down)
./scripts/jenkins/20-ci-build-and-push.sh --demo
./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag manual-test
./scripts/jenkins/32-cd-verify-deployment.sh --demo
```

#### Cost Management

```bash
# Stop EC2 Jenkins when not in use (save $15-20/month)
./scripts/jenkins/94-stop-jenkins-ec2.sh --demo

# Start EC2 Jenkins when needed
./scripts/jenkins/93-start-jenkins-ec2.sh --demo
```

#### Cleanup When Done

```bash
# Delete the CloudFormation stack (SAM resources)
sam delete --config-file aws/samconfig-demo.toml --stack-name flask-demo-backend --region us-east-1

# Remove any test images (optional)
aws ecr batch-delete-image --repository-name aws-lab-flask-demo --image-ids imageTag=manual-test
```

## Script Organization

- `scripts/local/` – manual smoke tests (`test-local.sh`, `build-local.sh`) that never touch AWS.
- `scripts/jenkins/` – Jenkins bootstrap, CI/CD runners (`20-`, `30-` series), and EC2 utilities (`40-`, `41-`, `93-`, `94-`).

See `docs/scripts.md` for one-line descriptions and usage examples for every script.

## Dual Backend Usage

### Demo Backend (Validation)

```bash
# Test the demo Flask app
./scripts/local/test-local.sh --demo

# Build demo Docker image
./scripts/local/build-local.sh --demo

# Used for: CI/CD validation, testing pipeline
```

### Production Backend (Your Service)

```bash
# Test your production service
./scripts/local/test-local.sh

# Build production Docker image
./scripts/local/build-local.sh

# Used for: Real production deployments
```

### Jenkins Parameter

When running Jenkins manually, select:

- **BACKEND_DIR: demo-backend** - For testing the CI/CD pipeline
- **BACKEND_DIR: backend** - For deploying production service

## API Endpoints

### GET /health

Health check endpoint for monitoring.

**Request:**

```bash
curl http://localhost:8000/health
# OR (AWS deployed):
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health
```

**Response:**

```json
{
  "status": "ok",
  "service": "demo-backend"
}
```

**Status:** 200 OK

### POST /echo

Echo endpoint that returns the request body.

**Request:**

```bash
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "hello", "data": {"nested": "value"}}'
```

**Response:**

```json
{
  "body": {
    "message": "hello",
    "data": {
      "nested": "value"
    }
  }
}
```

**Status:** 200 OK

## Development Workflows

### Daily Development (Jeffery Branch)

```bash
# 1. Always work on Jeffery branch
git checkout Jeffery

# 2. Make changes and test locally
./scripts/local/test-local.sh --demo

# 3. Commit and push (Jenkins runs CI automatically)
git add .
git commit -m "feat: add new feature"
git push origin Jeffery

# 4. Jenkins tests and builds (no AWS deployment)

# 5. Repeat as needed
```

### Production Release (Main Branch)

```bash
# 1. Ensure Jeffery CI passes
git checkout Jeffery
git push origin Jeffery
# Wait for Jenkins green build

# 2. Merge to main
git checkout main
git merge Jeffery
git push origin main

# 3. Trigger flask-cd manually to deploy the selected image tag
#    - Jenkins UI → flask-cd → Build with Parameters
#    - BACKEND_DIR: backend (or demo-backend for dry-run)
#    - IMAGE_TAG: leave blank to auto-deploy the most recent CI image

# 4. Verify deployment
./scripts/jenkins/32-cd-verify-deployment.sh --prod
```

### Fixing Production Issues

```bash
# Option 1: Fix on Jeffery, test, then merge (recommended)
git checkout Jeffery
# Fix issue
git commit -m "fix: production issue"
git push origin Jeffery
# Wait for CI to pass
git checkout main && git merge Jeffery && git push

# Option 2: Hotfix directly on main (use sparingly)
git checkout main
# Fix critical issue
git commit -m "hotfix: critical issue"
git push origin main
# Deploys immediately
# Then backport: git checkout Jeffery && git merge main
```

## Automation Scripts

### Local Development Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/jenkins/40-setup-jenkins-local.sh` | Boot Jenkins in Docker (local dry-run) | One-time per machine |
| `scripts/local/test-local.sh` | Run pytest tests | Before commits |
| `scripts/local/build-local.sh` | Build Docker image locally | When debugging Dockerfile |

### AWS Deployment Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `scripts/jenkins/11-setup-ecr.sh` | Create (or confirm) the shared ECR repo | Once per environment |
| `scripts/jenkins/20-ci-build-and-push.sh` | pytest → Docker build → push to ECR | Manual CI dry-run or Jenkins CI |
| `scripts/jenkins/30-cd-validate-sam.sh` | Validate SAM template + LabRole | Before any SAM deploy |
| `scripts/jenkins/31-cd-deploy-sam.sh` | Deploy a specific image tag via SAM | Manual CD dry-run or Jenkins CD |
| `scripts/jenkins/32-cd-verify-deployment.sh` | Hit `/health` and `/echo` after deploy | Post-deployment smoke test |
| `scripts/jenkins/41-setup-jenkins-ec2.sh` | Provision Jenkins on EC2 | When standing up the shared controller |
| `scripts/jenkins/42-configure-jenkins-jobs.sh` | Create `flask-ci` and `flask-cd` jobs via API (`--local` or `--ec2`) | Right after Jenkins is ready |
| `scripts/jenkins/91-check-jenkins-status.sh` | Inspect EC2 Jenkins state/logs | Troubleshooting |
| `scripts/jenkins/93-start-jenkins-ec2.sh` / `94-stop-jenkins-ec2.sh` | Control EC2 uptime/cost | Daily start/stop cycle |

**All scripts include:**

- Detailed command explanations
- Color-coded output
- Error handling
- Idempotent design (safe to run multiple times)

See [scripts/README.md](scripts/README.md) for comprehensive documentation.

## Technology Stack

- **Python 3.11** - AWS Lambda runtime
- **Flask 3.0** - Web framework
- **Gunicorn 21.2** - WSGI server
- **Pytest 7.4** - Testing framework
- **Docker** - Containerization
- **Jenkins** - CI/CD automation
- **AWS ECR** - Container registry
- **AWS Lambda** - Serverless compute (container mode)
- **AWS API Gateway** - HTTP API
- **AWS CloudWatch** - Logging & monitoring
- **AWS SAM** - Infrastructure as Code
- **GitHub Webhooks** - Automatic CI triggers (Jeffery branch)

## Cost Management

### Jeffery Branch (CI Only)

- **Cost:** $0
- **Builds:** Unlimited
- **Resources:** Local Docker only

### Main Branch (CI + CD)

- **ECR Storage:** ~$0.03/month
- **Lambda:** Free tier (1M requests/month)
- **API Gateway:** Free tier
- **CloudWatch:** Free tier (5GB/month)
- **Total:** ~$0.03-0.12/month for light usage

**Recommendation:** Run `./scripts/jenkins/99-cleanup-all.sh` between testing sessions.

## Troubleshooting

### Tests Fail Locally

```bash
# Run verbose tests to see failures
./scripts/local/test-local.sh --demo

# Check specific test file
cd demo-backend
pytest tests/unit/test_health.py -v
```

### Docker Build Fails

```bash
# Verify Docker is running
docker ps

# Clear cache and rebuild
docker system prune -a
./scripts/local/build-local.sh --demo
```

### AWS Credentials Expired (Learner Lab)

```bash
# 1. Open AWS Learner Lab
# 2. Click "AWS Details"
# 3. Copy credentials to ~/.aws/credentials
# 4. Verify:
aws sts get-caller-identity
```

### Jenkins Build Fails

```bash
# Check Jenkins logs
docker logs jenkins-local

# Check pipeline stage output in Blue Ocean
# http://localhost:8080/blue
```

### ECR Authentication Failed

```bash
# Re-authenticate to ECR and rebuild/push
./scripts/jenkins/20-ci-build-and-push.sh --demo
# Script handles authentication automatically
```

## Validation & Success Criteria

### Phase 6 Validation Checklist

- ✅ All 18 tests pass locally
- ✅ Jeffery branch runs CI successfully
- ✅ Manual `flask-cd` run deploys the selected image tag to AWS
- ✅ API Gateway endpoints respond correctly
- ✅ CloudWatch logs show invocations
- ✅ Pipeline completes in < 10 minutes
- ✅ Cleanup script removes all resources

### Testing the Complete Pipeline

1. **Local Tests:** `./scripts/local/test-local.sh --demo`
2. **Jeffery CI:** `git push origin Jeffery` (should build but not deploy)
3. **Main Deployment:** `git push origin main` (should deploy to AWS)
4. **API Test:** `./scripts/jenkins/05-verify-deployment.sh`
5. **Cleanup:** `./scripts/jenkins/99-cleanup-all.sh`

## Additional Documentation

- **[BRANCH_STRATEGY.md](BRANCH_STRATEGY.md)** - Complete branch workflow and CI/CD strategy
- **[COLLABORATION.md](COLLABORATION.md)** - Guide for team collaboration
- **[docs/archived/DEVELOPMENT_DIARY.md](docs/archived/DEVELOPMENT_DIARY.md)** - Implementation history and decisions
- **[scripts/README.md](scripts/README.md)** - Comprehensive script documentation
- **[CLAUDE.md](CLAUDE.md)** - Developer guide for Claude Code
- **[specs/](specs/)** - Detailed planning and specification documents

## Learning Objectives

This project demonstrates:

1. ✅ **Complete CI/CD Pipeline** from code to production
2. ✅ **Branch-Based Deployment Strategy** for safe releases
3. ✅ **Infrastructure as Code** with AWS SAM
4. ✅ **Container-Based Serverless** with Lambda
5. ✅ **Automated Testing** with pytest
6. ✅ **DevOps Automation** with comprehensive scripts
7. ✅ **Cloud-Native Logging** with CloudWatch
8. ✅ **Cost-Effective Development** with local CI option

## Project Status

Phase 6 COMPLETE - Production ready!

- [x] Phase 0: Planning and specification
- [x] Phase 1: Local Flask implementation
- [x] Phase 2: Docker containerization
- [x] Phase 3: Jenkins CI pipeline
- [x] Phase 4: GitHub webhook automation
- [x] Phase 6: Complete AWS deployment automation ⭐

**Next Steps for Users:**

1. Use demo-backend to validate the complete CI/CD pipeline
2. Implement your production service in backend/
3. Deploy to AWS with confidence using the proven automation

## Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Jenkins Pipeline](https://www.jenkins.io/doc/book/pipeline/)
- [AWS Lambda Containers](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/)
- [Pytest Documentation](https://docs.pytest.org/)

## License

Educational project for AWS Learner Lab demonstration purposes.

---

**Made with:** Python 3.11 | Flask | Docker | Jenkins | AWS Lambda | AWS SAM

**Deployment:** Branch-based CI/CD with full AWS automation

**Status:** Phase 6 Complete - Production Ready ✅
