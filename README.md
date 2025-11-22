# AWS Learner Lab Flask CI/CD Demo

**Phase 6 COMPLETE** - Full end-to-end automated CI/CD pipeline with AWS Lambda deployment

A comprehensive demonstration project showcasing a complete CI/CD pipeline from local Flask development to automated AWS Lambda deployment with branch-based deployment strategy and webhook automation.

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

### Progressive Implementation (6 Phases)

1. ✅ **Phase 0** - Planning & specification
2. ✅ **Phase 1** - Local Flask REST API
3. ✅ **Phase 2** - Docker containerization
4. ✅ **Phase 3** - Local Jenkins CI/CD
5. ✅ **Phase 4** - GitHub webhook automation
6. ✅ **Phase 6** - **Complete AWS deployment automation** (CURRENT)

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
│   └── Jenkinsfile        # Parameterized pipeline (demo vs prod)
│
├── aws/
│   ├── template.yaml      # SAM infrastructure template
│   ├── samconfig-demo.toml   # Demo deployment config
│   └── samconfig-prod.toml   # Production deployment config
│
├── scripts/
│   ├── local/             # Local development scripts
│   │   ├── setup-jenkins.sh
│   │   ├── test-local.sh
│   │   └── build-local.sh
│   └── aws/               # AWS deployment automation
│       ├── 01-check-prerequisites.sh
│       ├── 02-setup-ecr.sh
│       ├── 03-build-and-push.sh
│       ├── 04-deploy-sam.sh
│       ├── 05-verify-deployment.sh
│       ├── check-aws-status.sh
│       └── 99-cleanup-all.sh
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
./scripts/local/setup-jenkins.sh

# Access Jenkins at http://localhost:8080
# Follow on-screen instructions to configure pipeline
```

#### Step 2: Development Workflow (Jeffery Branch)
```bash
# Make changes on Jeffery branch
git checkout Jeffery
# ... edit code ...

# Test locally (optional but recommended)
./scripts/local/test-local.sh --demo

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

#### AWS Setup (One-Time)
```bash
# 1. Verify AWS environment
./scripts/aws/01-check-prerequisites.sh

# 2. Create ECR repository
./scripts/aws/02-setup-ecr.sh
```

#### Deploy to AWS
```bash
# 3. Build and push Docker image to ECR
./scripts/aws/03-build-and-push.sh

# 4. Deploy to Lambda via SAM
./scripts/aws/04-deploy-sam.sh

# 5. Verify deployment
./scripts/aws/05-verify-deployment.sh
```

#### Check Status Anytime
```bash
# See all AWS resources and costs
./scripts/aws/check-aws-status.sh
```

#### Cleanup When Done
```bash
# Delete all AWS resources to avoid costs
./scripts/aws/99-cleanup-all.sh
```

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

# 3. Jenkins deploys to AWS automatically

# 4. Verify deployment
./scripts/aws/05-verify-deployment.sh
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
| `scripts/local/setup-jenkins.sh` | Setup Jenkins container | One-time setup |
| `scripts/local/test-local.sh` | Run pytest tests | Before commits |
| `scripts/local/build-local.sh` | Build Docker image | Test builds |

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

**Recommendation:** Run `./scripts/aws/99-cleanup-all.sh` between testing sessions.

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
# Re-authenticate to ECR
./scripts/aws/03-build-and-push.sh
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

1. **Local Tests:** `./scripts/local/test-local.sh --demo`
2. **Jeffery CI:** `git push origin Jeffery` (should build but not deploy)
3. **Main Deployment:** `git push origin main` (should deploy to AWS)
4. **API Test:** `./scripts/aws/05-verify-deployment.sh`
5. **Cleanup:** `./scripts/aws/99-cleanup-all.sh`

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
