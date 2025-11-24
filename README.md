# AWS Learner Lab Flask CI/CD Demo

**Phase 7 COMPLETE** - Production-ready CI/CD with Jenkins EC2, separated CI/CD pipelines, and organized scripts

A comprehensive demonstration project showcasing a complete CI/CD pipeline from local Flask development to automated AWS Lambda deployment with Jenkins on EC2, CI/CD separation, branch-based deployment strategy, and comprehensive automation.

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
3. ✅ **Phase 3a** - **Manual CI testing** (build/push WITHOUT Jenkins) ⚡ NEW
4. ✅ **Phase 3b** - **Manual CD testing** (deploy/verify WITHOUT Jenkins) ⚡ NEW
5. ✅ **Phase 4** - **Jenkinsfile preparation** (define pipelines as code) ⚡ NEW
6. ✅ **Phase 5** - **Jenkins EC2 deployment** (one-time, pulls from Git)
7. ✅ **Phase 6** - **Jenkins pipeline testing** (validate CI and CD separately)
8. ✅ **Phase 7** - **End-to-end automation** (webhooks → Jenkins → AWS)
9. ✅ **Phase 8** - **Implementation order refinement** (CURRENT)

### Phase 8 Highlights

- **Prove → Codify → Automate**: Manual testing BEFORE Jenkins deployment
- **One-Time EC2 Deploy**: No redeploy cycles (67-75% time savings)
- **Git-Committed Pipelines**: Jenkinsfile-CI and Jenkinsfile-CD in version control
- **Separate Testing**: Validate CI (build/push) and CD (deploy/verify) independently
- **Higher Confidence**: Jenkins automates proven steps (we already know they work!)
- **Better IaC**: Pipeline definitions are code, not Jenkins UI configuration
- **Folder Clarity**: `local-ci-only` vs `aws-ci-cd` for explicit purpose
- **Rollback Capability**: Deploy any previous ECR image version
- **Cost Management**: Start/stop EC2 scripts for budget control

### Branch-Based CI/CD Strategy

| Branch | Pipeline Mode | Stages | Deployment | Use Case |
|--------|--------------|--------|------------|----------|
| **Jeffery** | CI Only | 6 stages | None | Daily development & testing |
| **main** | Full CI/CD | 9 stages | AWS Lambda | Production releases |

**Jeffery Branch (Development):**
- Checkout → Setup → Install → Test → Build → Done
- Fast feedback without AWS costs
- Safe for experimentation

**Main Branch (Production):**
- All CI stages + ECR Login → Push to ECR → Deploy to Lambda
- Full deployment to AWS
- Production-ready releases

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
│   ├── local-ci-only/     # Local CI scripts (no AWS deployment)
│   │   ├── setup-jenkins.sh
│   │   ├── test-local.sh
│   │   └── build-local.sh
│   └── aws-ci-cd/         # Full CI/CD pipeline in AWS
│       ├── 10-check-prerequisites.sh    # Setup: Verify AWS access
│       ├── 11-setup-ecr.sh              # Setup: Create ECR repo
│       ├── 12-setup-jenkins-ec2.sh      # Setup: Launch Jenkins on EC2
│       ├── 13-configure-jenkins-jobs.sh # Setup: Create CI/CD jobs
│       ├── 20-ci-build-and-push.sh      # CI: Build + push image
│       ├── 21-ci-validate-image.sh      # CI: Verify image in ECR
│       ├── 30-cd-validate-sam.sh        # CD: Validate SAM template
│       ├── 31-cd-deploy-sam.sh          # CD: Deploy to Lambda
│       ├── 32-cd-verify-deployment.sh   # CD: Test endpoints
│       ├── 33-cd-redeploy-image.sh      # CD: Redeploy existing image
│       ├── 34-cd-rollback.sh            # CD: Rollback to previous
│       ├── 90-check-aws-status.sh       # Utility: Check resources
│       ├── 91-check-jenkins-status.sh   # Utility: Check Jenkins EC2
│       ├── 92-view-cd-logs.sh           # Utility: View deployment logs
│       ├── 93-start-jenkins-ec2.sh      # Utility: Start EC2
│       ├── 94-stop-jenkins-ec2.sh       # Utility: Stop EC2
│       └── 99-cleanup-all.sh            # Cleanup: Delete everything
│
├── specs/                 # Complete planning documentation
├── BRANCH_STRATEGY.md     # Detailed workflow guide
├── COLLABORATION.md       # Team collaboration guide
├── DEVELOPMENT_DIARY.md   # Implementation history
└── README.md             # This file
```

## Prerequisites

- **Python 3.11** (AWS Lambda compatibility requirement)
- **Docker** Desktop running
- **Git** for version control
- **AWS Account** (AWS Learner Lab recommended)
- **AWS CLI** configured with credentials
- **AWS SAM CLI** for infrastructure deployment

## Quick Start

### Option 1: Fully Automated (Recommended)

#### Step 1: Local Jenkins Setup
```bash
# One-time setup: Start Jenkins with all prerequisites
./scripts/local-ci-only/setup-jenkins.sh

# Access Jenkins at http://localhost:8080
# Follow on-screen instructions to configure pipeline
```

#### Step 2: Development Workflow (Jeffery Branch)
```bash
# Make changes on Jeffery branch
git checkout Jeffery
# ... edit code ...

# Test locally (optional but recommended)
./scripts/local-ci-only/test-local.sh --demo

# Commit and push (triggers Jenkins CI automatically via webhook)
git add .
git commit -m "feat: your feature description"
git push origin Jeffery

# Jenkins automatically:
# - Runs all 18 tests
# - Builds Docker image
# - Shows results in ~2 minutes
# - Does NOT deploy to AWS (CI only)
```

#### Step 3: Production Deployment (Main Branch)
```bash
# When ready for production, merge to main
git checkout main
git merge Jeffery
git push origin main

# Jenkins automatically:
# - Runs all tests
# - Builds Docker image
# - Pushes to AWS ECR
# - Deploys to Lambda via SAM
# - Provides API Gateway URL
```

### Option 2: Manual Deployment (No Jenkins)

#### Phase 1-2: Infrastructure Setup (One-Time)
```bash
# 1. Verify AWS environment
./scripts/aws-ci-cd/10-check-prerequisites.sh

# 2. Create ECR repository
./scripts/aws-ci-cd/11-setup-ecr.sh
```

#### Phase 3: Manual SAM Validation (Critical Gate)
```bash
# IMPORTANT: Validate SAM works manually before Jenkins automation

# 3. Build and push first Docker image
./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo

# 4. Validate SAM template
./scripts/aws-ci-cd/30-cd-validate-sam.sh --demo

# 5. Deploy to Lambda manually (first time)
./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo

# 6. Verify deployment works
./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo

# ✅ If all succeed, proceed to Phase 4
```

#### Phase 4: Jenkins on EC2 (Automation)
```bash
# 7. Launch Jenkins on EC2 instance
./scripts/aws-ci-cd/12-setup-jenkins-ec2.sh --demo

# 8. Configure CI and CD Jenkins jobs
./scripts/aws-ci-cd/13-configure-jenkins-jobs.sh --demo

# ✅ Now push to GitHub triggers full CI/CD automatically!
```

#### Daily Operations (After Setup)
```bash
# Normal workflow: Just push to GitHub
git push origin Jeffery  # Triggers CI → CD to demo-backend

# Check AWS resources status
./scripts/aws-ci-cd/90-check-aws-status.sh --demo

# Check Jenkins EC2 status
./scripts/aws-ci-cd/91-check-jenkins-status.sh --demo

# View deployment logs (if CD fails)
./scripts/aws-ci-cd/92-view-cd-logs.sh --demo
```

#### Recovery Operations
```bash
# Rollback to previous version
./scripts/aws-ci-cd/34-cd-rollback.sh --demo

# Redeploy existing image (without rebuild)
./scripts/aws-ci-cd/33-cd-redeploy-image.sh --demo --image-tag jeffery-42

# Manual deployment (if Jenkins down)
./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo
./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo
```

#### Cost Management
```bash
# Stop EC2 Jenkins when not in use (save $15-20/month)
./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --demo

# Start EC2 Jenkins when needed
./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --demo
```

#### Cleanup When Done
```bash
# Delete all AWS resources to avoid costs
./scripts/aws-ci-cd/99-cleanup-all.sh --demo
```

## Script Organization

### Folder Structure

```
scripts/
├── local-ci-only/    # CI testing without AWS deployment
│   ├── setup-jenkins.sh
│   ├── test-local.sh
│   └── build-local.sh
│
└── aws-ci-cd/        # Full CI/CD pipeline in AWS
    ├── 10-19: Infrastructure setup (one-time)
    ├── 20-29: CI operations (build, test, push)
    ├── 30-39: CD operations (deploy, verify, rollback)
    └── 90-99: Utilities and cleanup
```

### Script Numbering Convention

- **10-19**: Infrastructure Setup (run once)
  - 10-check-prerequisites.sh
  - 11-setup-ecr.sh
  - 12-setup-jenkins-ec2.sh
  - 13-configure-jenkins-jobs.sh

- **20-29**: CI Operations (build/test/push)
  - 20-ci-build-and-push.sh
  - 21-ci-validate-image.sh

- **30-39**: CD Operations (deploy/verify/rollback)
  - 30-cd-validate-sam.sh
  - 31-cd-deploy-sam.sh
  - 32-cd-verify-deployment.sh
  - 33-cd-redeploy-image.sh
  - 34-cd-rollback.sh

- **90-99**: Utilities and Cleanup
  - 90-check-aws-status.sh
  - 91-check-jenkins-status.sh
  - 92-view-cd-logs.sh
  - 93-start-jenkins-ec2.sh
  - 94-stop-jenkins-ec2.sh
  - 99-cleanup-all.sh

## Dual Backend Usage

### Demo Backend (Validation)
```bash
# Test the demo Flask app
./scripts/local-ci-only/test-local.sh --demo

# Build demo Docker image
./scripts/local-ci-only/build-local.sh --demo

# Used for: CI/CD validation, testing pipeline
```

### Production Backend (Your Service)
```bash
# Test your production service
./scripts/local-ci-only/test-local.sh

# Build production Docker image
./scripts/local-ci-only/build-local.sh

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
./scripts/local-ci-only/test-local.sh --demo

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

# 3. Jenkins deploys to AWS automatically

# 4. Verify deployment
./scripts/aws-ci-cd/05-verify-deployment.sh
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
| `scripts/local-ci-only/setup-jenkins.sh` | Setup Jenkins container | One-time setup |
| `scripts/local-ci-only/test-local.sh` | Run pytest tests | Before commits |
| `scripts/local-ci-only/build-local.sh` | Build Docker image | Test builds |

### AWS Deployment Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `01-check-prerequisites.sh` | Verify AWS environment | FIRST before deployment |
| `02-setup-ecr.sh` | Create ECR repository | Once per project |
| `03-build-and-push.sh` | Build & push to ECR | Every code update |
| `04-deploy-sam.sh` | Deploy to Lambda | After ECR push |
| `05-verify-deployment.sh` | Test deployment | After deploy |
| `check-aws-status.sh` | View all resources | Anytime |
| `99-cleanup-all.sh` | Delete everything | When done |

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
- **GitHub Webhooks** - Automated triggers

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

**Recommendation:** Run `./scripts/aws-ci-cd/99-cleanup-all.sh` between testing sessions.

## Troubleshooting

### Tests Fail Locally
```bash
# Run verbose tests to see failures
./scripts/local-ci-only/test-local.sh --demo

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
./scripts/local-ci-only/build-local.sh --demo
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
# Re-authenticate to ECR
./scripts/aws-ci-cd/03-build-and-push.sh
# Script handles authentication automatically
```

## Validation & Success Criteria

### Phase 6 Validation Checklist

- ✅ All 18 tests pass locally
- ✅ Jeffery branch runs CI successfully
- ✅ Main branch deploys to AWS
- ✅ API Gateway endpoints respond correctly
- ✅ CloudWatch logs show invocations
- ✅ Pipeline completes in < 10 minutes
- ✅ Cleanup script removes all resources

### Testing the Complete Pipeline

1. **Local Tests:** `./scripts/local-ci-only/test-local.sh --demo`
2. **Jeffery CI:** `git push origin Jeffery` (should build but not deploy)
3. **Main Deployment:** `git push origin main` (should deploy to AWS)
4. **API Test:** `./scripts/aws-ci-cd/05-verify-deployment.sh`
5. **Cleanup:** `./scripts/aws-ci-cd/99-cleanup-all.sh`

## Additional Documentation

- **[BRANCH_STRATEGY.md](BRANCH_STRATEGY.md)** - Complete branch workflow and CI/CD strategy
- **[COLLABORATION.md](COLLABORATION.md)** - Guide for team collaboration
- **[DEVELOPMENT_DIARY.md](DEVELOPMENT_DIARY.md)** - Implementation history and decisions
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
