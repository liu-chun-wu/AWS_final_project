# Branch Strategy & CI/CD Workflow

This project uses a **branch-based CI/CD strategy** where different branches trigger different levels of automation.

## Branch Overview

| Branch | Purpose | Pipeline Stages | Deployment | Use Case |
|--------|---------|-----------------|------------|----------|
| **Jeffery** | Primary development + deployments | Auto CI via webhook (checkout → branch check → venv → deps → tests → Docker build/push); manual CD (validate → deploy via SAM → verify) | Manual `flask-cd` (demo-backend) | All work happens here; CD is an intentional, manual trigger |

---

## Jeffery Branch (Development)

### Purpose

Fast feedback loop for development work - tests and builds without deploying to AWS.

### Pipeline Stages

1. ✅ Checkout - Clone repository
2. ✅ Branch Check - Verify branch and set mode (CI only)
3. ✅ Setup Python - Create virtual environment
4. ✅ Install Dependencies - Install Flask, pytest, etc.
5. ✅ Run Tests - Execute all 18 tests
6. ✅ Build Docker - Create local Docker image

**Stages Skipped:**

- ⊘ Login to ECR (AWS only)
- ⊘ Push to ECR (AWS only)
- ⊘ Deploy to Lambda (AWS only)

### When Builds Trigger

- **Automatic:** On every `git push origin Jeffery` (via GitHub webhook)
- **Manual:** Click "Build Now" in Jenkins Blue Ocean

### Typical Workflow

```bash
# 1. Make changes on Jeffery branch
git checkout Jeffery
# ... edit code ...

# 2. Test locally (optional but recommended)
./scripts/local/test-local.sh

# 3. Commit and push (triggers Jenkins CI automatically)
git add .
git commit -m "feat: your feature description"
git push origin Jeffery

# 4. Jenkins automatically:
#    - Runs tests
#    - Builds Docker image locally
#    - Shows results in ~2 minutes

# 5. Check Jenkins Blue Ocean for results
#    http://localhost:8080/blue
```

### Benefits

- ⚡ Fast feedback (no AWS deployment overhead)
- 💰 No AWS costs for development
- 🔄 Unlimited builds without affecting production
- 🧪 Safe environment for experimentation

---

## Main Branch (Production)

> Note: Current Jenkinsfiles and jobs are restricted to the **Jeffery** branch for both CI and CD. The main branch section is retained for historical context; deployments should be triggered from Jeffery.

### Purpose

Production deployment - full CI/CD pipeline that deploys to AWS Lambda.

### Pipeline Stages

1. ✅ Checkout - Clone repository
2. ✅ Branch Check - Verify branch and set mode (full CI/CD)
3. ✅ Setup Python - Create virtual environment
4. ✅ Install Dependencies - Install Flask, pytest, etc.
5. ✅ Run Tests - Execute all 18 tests
6. ✅ Build Docker - Create Docker image
7. ✅ **Login to ECR** - Authenticate to AWS container registry
8. ✅ **Push to ECR** - Upload Docker image to AWS
9. ✅ **Deploy to Lambda** - Deploy via SAM to Lambda + API Gateway

### When Builds Trigger

- **Manual:** Run the `flask-cd` job (local or EC2 Jenkins) when you're ready to promote the approved image tag.

### Typical Workflow

```bash
# Option A: Merge Jeffery to main
git checkout main
git merge Jeffery
git push origin main
# Capture IMAGE_TAG from the latest CI build output
# Jenkins → flask-cd → Build with Parameters (BACKEND_DIR + IMAGE_TAG)

# Option B: Direct push to main (not recommended)
git checkout main
# ... edit code ...
git push origin main
# Immediately run flask-cd manually to deploy
```

### What Gets Deployed

- 🐳 Docker image pushed to AWS ECR
- λ Lambda function created/updated
- 🌐 API Gateway endpoints updated
- 📊 CloudWatch logs configured
- 🔐 IAM roles managed by SAM

### Deployment Outputs

After successful deployment, Jenkins displays:

- API Gateway URL: `https://xxx.execute-api.us-east-1.amazonaws.com/Prod/`
- Health endpoint: `.../health`
- Echo endpoint: `.../echo`
- Lambda function ARN
- CloudWatch log group

---

## Development Workflow (Recommended)

### Day-to-Day Development

```bash
# Always work on Jeffery branch
git checkout Jeffery

# Make changes → commit → push → Jenkins tests automatically
# Repeat as needed

# When feature is complete and tested:
git checkout main
git merge Jeffery
git push origin main
# Jenkins UI → flask-cd → Build with Parameters
```

### Fixing Production Issues

```bash
# Option 1: Fix on Jeffery, test, then merge
git checkout Jeffery
# Fix issue
git commit -m "fix: production issue description"
git push origin Jeffery
# Wait for CI to pass
git checkout main
git merge Jeffery
git push origin main

# Option 2: Hotfix directly on main (use sparingly)
git checkout main
# Fix issue
git commit -m "hotfix: critical issue"
git push origin main
# Run flask-cd manually to deploy the fix

# Then backport to Jeffery
git checkout Jeffery
git merge main
git push origin Jeffery
```

---

## Branch Protection (Future Enhancement)

### Recommended GitHub Settings

**For Jeffery Branch:**

- ✅ Require status checks before merging (Jenkins CI must pass)
- ✅ Require pull request reviews: 0 (development branch)
- ❌ Do NOT restrict pushes (allow direct commits)

**For Main Branch:**

- ✅ Require status checks before merging (Jenkins CI/CD must pass)
- ✅ Require pull request reviews: 1+ (protect production)
- ✅ Restrict pushes to administrators only
- ✅ Require branches to be up to date before merging

---

## Manual Deployment (Alternative to Jenkins)

If you want to deploy manually without Jenkins:

### Deploy to AWS Manually

```bash
# Prerequisites
./scripts/jenkins/01-check-prerequisites.sh

# Create ECR repository (one-time)
./scripts/jenkins/02-setup-ecr.sh

# Build and push image
./scripts/jenkins/03-build-and-push.sh

# Deploy to AWS
./scripts/jenkins/04-deploy-sam.sh

# Verify deployment
./scripts/jenkins/05-verify-deployment.sh
```

### Cleanup

```bash
# Remove all AWS resources
./scripts/jenkins/99-cleanup-all.sh
```

---

## Troubleshooting

### "Branch not configured for CI/CD"

**Problem:** Pushed to a branch other than Jeffery or main

**Solution:**

```bash
git checkout Jeffery  # or main
git cherry-pick <commit-hash>
git push
```

### "ECR authentication failed" (main branch only)

**Problem:** AWS credentials not configured in Jenkins

**Solution:**

1. Open Jenkins: Configure System
2. Add environment variable: `AWS_ACCOUNT_ID=123456789012`
3. Configure AWS credentials (Access Key + Secret Key)
4. Or use IAM role if Jenkins is on EC2

### "Tests pass locally but fail in Jenkins"

**Problem:** Environment differences

**Common causes:**

- Different Python version
- Missing dependencies
- Environment variables not set

**Solution:**

```bash
# Check Python version matches
python3 --version  # Should be 3.11+

# Ensure requirements.txt is complete
pip freeze > requirements.txt
git add requirements.txt
git commit -m "fix: update dependencies"
git push
```

---

## Best Practices

### ✅ DO

- Work on Jeffery branch for all development
- Run `./scripts/local/test-local.sh` before pushing
- Wait for Jeffery CI to pass before merging to main
- Review deployment outputs after main branch builds
- Clean up AWS resources when done testing

### ❌ DON'T

- Don't push directly to main for regular development
- Don't merge to main with failing tests
- Don't commit secrets or credentials
- Don't skip local testing
- Don't leave AWS resources running (costs money)

---

## Cost Management

### Jeffery Branch (CI Only)

- **Cost:** $0
- **Builds:** Unlimited
- **Resources:** Local Docker images only

### Main Branch (CI + CD)

- **ECR Storage:** ~$0.10/GB/month
- **Lambda Execution:** Free tier (1M requests/month)
- **API Gateway:** Free tier
- **CloudWatch Logs:** Free tier (5GB/month)
- **Total:** ~$0.03-0.12/month for development usage

**Recommendation:** Delete AWS resources between testing sessions using `./scripts/jenkins/99-cleanup-all.sh --demo`

---

## Script Organization

### Folder Structure

**scripts/local/**

- Used by: Local Jenkins (Jeffery branch)
- Purpose: CI testing without AWS deployment
- Scripts:
  - `40-setup-jenkins-local.sh` - Setup Jenkins container (Docker)
  - `test-local.sh` - Run tests locally
  - `build-local.sh` - Build Docker image locally

**scripts/jenkins/**

- Used by: Local Jenkins (for CD) and EC2 Jenkins
- Purpose: Shared CI/CD scripts (CI auto; CD triggered manually)
- Organization:
  - **10-19:** Infrastructure setup (one-time)
  - **20-29:** CI operations (build, test, push)
  - **30-39:** CD operations (deploy, verify, rollback)
  - **90-99:** Utilities and cleanup

### Which Scripts for Which Branch?

**Jeffery Branch:**

- **Local Jenkins:** Uses `scripts/local/*` for CI and can deploy via `flask-cd` when needed
- **AWS Jenkins:** Runs CI automatically; `flask-cd` can deploy to demo-backend manually

**Main Branch:**

- **AWS Jenkins:** Runs CI automatically; team triggers `flask-cd` with prod parameters to deploy
- **Manual:** Can use `scripts/jenkins/*` directly

---

## Summary

- **Jeffery = Fast, Safe, Free** → Use for daily development
- **Main = Complete, Deployed, Production** → Use for releases

This strategy gives you the best of both worlds:

1. Fast feedback during development (Jeffery)
2. Confidence before production (tests must pass on Jeffery)
3. Automated deployment (main)
4. Cost control (only deploy when ready)

---

For more information:

- Pipeline configuration: `ci/Jenkinsfile-CI` and `ci/Jenkinsfile-CD`
- Deployment scripts: `scripts/jenkins/`
- Local scripts: `scripts/local/`
- Script guide: `docs/scripts.md`
- Development diary: `docs/archived/DEVELOPMENT_DIARY.md` (see Phase 7)
