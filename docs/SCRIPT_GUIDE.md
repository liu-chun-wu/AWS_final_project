# Script Guide

Complete reference for all automation scripts in the AWS Flask CI/CD Demo project.

---

## Table of Contents

- [Overview](#overview)
- [Local CI-Only Scripts](#local-ci-only-scripts)
- [AWS CI/CD Scripts](#aws-cicd-scripts)
  - [10-19: Infrastructure Setup](#10-19-infrastructure-setup)
  - [20-29: CI Operations](#20-29-ci-operations)
  - [30-39: CD Operations](#30-39-cd-operations)
  - [90-99: Utilities](#90-99-utilities)

---

## Overview

### Folder Structure

```
scripts/
├── local-ci-only/    # CI testing without AWS deployment
└── aws-ci-cd/        # Full CI/CD pipeline in AWS
```

### Numbering Convention

- **10-19**: Infrastructure setup (run once)
- **20-29**: CI operations (build/test/push)
- **30-39**: CD operations (deploy/verify/rollback)
- **90-99**: Utilities and cleanup

### Required Flags

All AWS scripts require explicit backend selection:
- `--demo` - For demo-backend (development/testing)
- `--prod` - For production backend

**Why?** Prevents accidental production deployments.

---

## Local CI-Only Scripts

Located in `scripts/local-ci-only/`

### setup-jenkins.sh

**Purpose:** Setup local Jenkins container for CI testing

**Usage:**
```bash
./scripts/local-ci-only/setup-jenkins.sh
```

**What it does:**
1. Checks if Docker is running
2. Pulls Jenkins LTS image
3. Creates Jenkins container with:
   - Port 8080 (UI)
   - Port 50000 (agent communication)
   - Persistent volume for Jenkins data
4. Waits for Jenkins to start
5. Displays initial admin password

**Output:**
- Jenkins URL: `http://localhost:8080`
- Initial admin password printed to console

**Common Errors:**
- **Docker not running**: Start Docker Desktop
- **Port 8080 in use**: Stop other services or change port mapping

---

### test-local.sh

**Purpose:** Run pytest tests locally

**Usage:**
```bash
./scripts/local-ci-only/test-local.sh --demo
./scripts/local-ci-only/test-local.sh --prod
```

**Flags:**
- `--demo` - Test demo-backend
- `--prod` - Test backend (production)

**What it does:**
1. Activates Python environment
2. Changes to backend directory
3. Runs pytest with coverage
4. Reports test results

**Prerequisites:**
- Python 3.11 installed
- Dependencies installed (`pip install -r requirements.txt`)

---

### build-local.sh

**Purpose:** Build Docker image locally

**Usage:**
```bash
./scripts/local-ci-only/build-local.sh --demo
./scripts/local-ci-only/build-local.sh --prod
```

**What it does:**
1. Determines backend directory
2. Builds Docker image with tag `:local`
3. Displays image size
4. Lists local images

**Output:**
- Image: `aws-lab-flask-demo:local` (demo)
- Image: `aws-lab-flask-prod:local` (prod)

**Common Errors:**
- **No Dockerfile**: Check backend directory structure
- **Build fails**: Review Dockerfile syntax, check base image

---

## AWS CI/CD Scripts

Located in `scripts/aws-ci-cd/`

All scripts require `--demo` or `--prod` flag.

---

## 10-19: Infrastructure Setup

### 10-check-prerequisites.sh

**Purpose:** Verify AWS environment is ready

**Usage:**
```bash
./scripts/aws-ci-cd/10-check-prerequisites.sh
```

**What it checks:**
1. AWS CLI installed
2. AWS credentials configured
3. SAM CLI installed
4. Docker installed and running
5. Python 3.11 available
6. Region set to us-east-1

**Output:**
- ✅ All checks passed
- ❌ Missing prerequisites with fix instructions

**Fix Instructions:**
- AWS CLI: `brew install awscli` (macOS)
- SAM CLI: `brew tap aws/tap && brew install aws-sam-cli`
- Credentials: `aws configure` or use Learner Lab credentials

---

### 11-setup-ecr.sh

**Purpose:** Create ECR repository for Docker images

**Usage:**
```bash
./scripts/aws-ci-cd/11-setup-ecr.sh
```

**What it does:**
1. Checks if repository already exists
2. Creates ECR repository `aws-lab-flask-demo`
3. Sets up lifecycle policy (delete untagged images after 1 day)
4. Displays repository URI

**Output:**
- Repository URI: `<account-id>.dkr.ecr.us-east-1.amazonaws.com/aws-lab-flask-demo`

**Run:** Once per AWS account

**Cost:** ~$0.10/GB/month for storage

---

### 12-setup-jenkins-ec2.sh

**Purpose:** Launch Jenkins on EC2 instance

**Usage:**
```bash
./scripts/aws-ci-cd/12-setup-jenkins-ec2.sh --demo
./scripts/aws-ci-cd/12-setup-jenkins-ec2.sh --prod
```

**What it does:**
1. Creates security group (SSH 22, Jenkins 8080, HTTPS 443)
2. Creates instance profile with LabRole
3. Launches t2.small EC2 instance
4. User Data script installs:
   - Java 17
   - Jenkins LTS
   - Docker
   - AWS CLI v2
   - SAM CLI
   - Git
5. Waits for instance ready (~10-15 minutes)
6. Retrieves Jenkins initial admin password

**Output:**
- Instance ID
- Public IP address
- Jenkins URL: `http://<EC2-IP>:8080`
- Initial admin password

**Prerequisites:**
- IAM permissions for EC2
- Available Learner Lab budget

**Duration:** ~15 minutes

**Cost:** ~$0.02/hour ($15/month if always on)

---

### 13-configure-jenkins-jobs.sh

**Purpose:** Create CI and CD Jenkins jobs

**Usage:**
```bash
./scripts/aws-ci-cd/13-configure-jenkins-jobs.sh --demo
./scripts/aws-ci-cd/13-configure-jenkins-jobs.sh --prod
```

**What it does:**
1. Installs required Jenkins plugins (Git, Docker Pipeline, GitHub)
2. Creates `flask-ci` job (uses Jenkinsfile-CI)
3. Creates `flask-cd` job (uses Jenkinsfile-CD)
4. Configures GitHub webhook credentials
5. Tests job creation

**Output:**
- flask-ci job URL
- flask-cd job URL
- GitHub webhook URL for configuration

**Prerequisites:**
- Jenkins EC2 instance running
- Jenkins accessible
- Repository URL configured

---

## 20-29: CI Operations

### 20-ci-build-and-push.sh

**Purpose:** Build Docker image and push to ECR

**Usage:**
```bash
./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo
./scripts/aws-ci-cd/20-ci-build-and-push.sh --prod
```

**What it does:**
1. Determines backend directory
2. Builds Docker image
3. Tags image with `:latest`
4. Logs into ECR
5. Tags image for ECR
6. Pushes to ECR

**Output:**
- Local image: `aws-lab-flask-demo:latest`
- ECR image: `<ecr-uri>:latest`

**Duration:** ~3-4 minutes

**Prerequisites:**
- ECR repository exists
- Docker running
- AWS credentials valid

**Common Errors:**
- **ECR login failed**: Check AWS credentials
- **Push denied**: Verify IAM permissions

---

### 21-ci-validate-image.sh

**Purpose:** Verify Docker image exists in ECR

**Usage:**
```bash
./scripts/aws-ci-cd/21-ci-validate-image.sh --demo --image-tag latest
./scripts/aws-ci-cd/21-ci-validate-image.sh --demo --image-tag jeffery-42
```

**Flags:**
- `--image-tag TAG` - Image tag to verify (default: latest)

**What it does:**
1. Queries ECR for specified image tag
2. Displays image details (size, push date)
3. Exits with error if not found

**Use Cases:**
- Verify CI pushed image correctly
- Check if specific tag exists before deploying
- Troubleshoot missing images

---

## 30-39: CD Operations

### 30-cd-validate-sam.sh

**Purpose:** Validate SAM template before deployment

**Usage:**
```bash
./scripts/aws-ci-cd/30-cd-validate-sam.sh --demo
./scripts/aws-ci-cd/30-cd-validate-sam.sh --prod
```

**What it checks:**
1. SAM template syntax (`sam validate`)
2. ECR repository exists
3. At least one image in ECR
4. LabRole exists
5. SAM build succeeds

**Output:**
- ✅ All validations passed - safe to deploy
- ❌ Validation failed with specific error

**Run:** Before first SAM deployment or after template changes

**Critical:** This is a GATE - must pass before Phase 4

---

### 31-cd-deploy-sam.sh

**Purpose:** Deploy to AWS Lambda via SAM

**Usage:**
```bash
./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo
./scripts/aws-ci-cd/31-cd-deploy-sam.sh --prod
```

**What it does:**
1. Changes to aws/ directory
2. Runs `sam build`
3. Runs `sam deploy` with appropriate config:
   - `--demo` uses `samconfig-demo.toml`
   - `--prod` uses `samconfig-prod.toml`
4. Waits for CloudFormation stack creation/update
5. Displays stack outputs (API URL, Lambda ARN)

**Output:**
- Stack name: `flask-demo-backend` or `flask-prod-backend`
- API Gateway URL
- Lambda function ARN

**Duration:** ~2-4 minutes

**Prerequisites:**
- ECR image exists
- LabRole configured in template.yaml
- Valid SAM template

**Common Errors:**
- **IAM permissions**: Ensure using LabRole
- **Image not found**: Run `20-ci-build-and-push.sh` first
- **Stack exists**: SAM will update existing stack

---

### 32-cd-verify-deployment.sh

**Purpose:** Test deployed Lambda endpoints

**Usage:**
```bash
./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo
./scripts/aws-ci-cd/32-cd-verify-deployment.sh --prod
```

**What it does:**
1. Gets API Gateway URL from CloudFormation outputs
2. Tests `/health` endpoint (expects `{"status": "ok"}`)
3. Tests `/echo` endpoint (sends JSON, expects echo back)
4. Displays response times
5. Checks CloudWatch logs

**Output:**
- ✅ Health check passed
- ✅ Echo test passed
- Response times
- Recent CloudWatch log entries

**Use Cases:**
- Verify deployment succeeded
- Confirm Lambda is responding
- Check basic functionality

---

### 33-cd-redeploy-image.sh

**Purpose:** Deploy existing ECR image without rebuilding

**Usage:**
```bash
./scripts/aws-ci-cd/33-cd-redeploy-image.sh --demo --image-tag jeffery-42
./scripts/aws-ci-cd/33-cd-redeploy-image.sh --prod --image-tag main-5
```

**Required Flags:**
- `--image-tag TAG` - Specific ECR image tag to deploy

**What it does:**
1. Verifies image tag exists in ECR
2. Updates SAM template to use specified tag
3. Runs SAM deployment with that image
4. Verifies deployment

**Use Cases:**
- CD failed due to SAM config error (image is fine)
- Want to deploy specific version for testing
- Redeploy after fixing template.yaml

**Time Saved:** ~3-4 minutes (no rebuild needed)

---

### 34-cd-rollback.sh

**Purpose:** Rollback to previous image version

**Usage:**
```bash
./scripts/aws-ci-cd/34-cd-rollback.sh --demo
./scripts/aws-ci-cd/34-cd-rollback.sh --prod
```

**What it does:**
1. Lists last 5 ECR images with timestamps
2. Prompts to select which version to deploy
3. Deploys selected image version
4. Verifies deployment

**Interactive:** Yes - prompts for version selection

**Use Cases:**
- New deployment has bugs
- Need to quickly revert to working version
- Testing different versions

**Example Output:**
```
Recent ECR images:
1. jeffery-45 (2025-11-23 14:30:22)
2. jeffery-44 (2025-11-23 13:15:10)
3. jeffery-43 (2025-11-23 11:05:33)

Select image to deploy (1-3): 2
```

---

## 90-99: Utilities

### 90-check-aws-status.sh

**Purpose:** Display current AWS resource status

**Usage:**
```bash
./scripts/aws-ci-cd/90-check-aws-status.sh --demo
./scripts/aws-ci-cd/90-check-aws-status.sh --prod
```

**What it shows:**
1. ECR repository status
   - Repository URI
   - Number of images
   - Latest image tags
2. CloudFormation stack status
   - Stack name
   - Creation time
   - Stack resources
   - Stack outputs
3. Lambda function status
   - Function name
   - Runtime (PackageType)
   - Memory/Timeout configuration
   - Last modified
4. API Gateway status
   - Base URL
   - Health endpoint
   - Echo endpoint
5. CloudWatch Logs status
   - Log group name
   - Number of log streams
6. Estimated monthly costs

**Use Cases:**
- Check what's deployed
- Get API Gateway URL
- Verify resources exist
- Monitor costs

**Output:** Comprehensive status report with resource details

---

### 91-check-jenkins-status.sh

**Purpose:** Monitor EC2 Jenkins instance health

**Usage:**
```bash
./scripts/aws-ci-cd/91-check-jenkins-status.sh --demo
./scripts/aws-ci-cd/91-check-jenkins-status.sh --prod
```

**What it shows:**
1. EC2 instance state (running/stopped)
2. Instance details (type, IP, launch time)
3. Jenkins service status (via SSH)
4. Jenkins URL and credentials
5. Recent builds
6. Resource usage (CPU, memory, disk)

**Use Cases:**
- Check if Jenkins is running
- Get Jenkins URL
- Monitor resource usage
- Troubleshoot Jenkins issues

**Prerequisites:**
- EC2 instance exists
- SSH key available

---

### 92-view-cd-logs.sh

**Purpose:** View deployment logs for troubleshooting

**Usage:**
```bash
./scripts/aws-ci-cd/92-view-cd-logs.sh --demo
./scripts/aws-ci-cd/92-view-cd-logs.sh --prod
```

**What it shows:**
1. CloudFormation stack events (last 20)
   - Resource creation/update status
   - Failure reasons
2. SAM deployment logs
   - Build output
   - Deploy progress
3. Lambda function logs (tail)
   - Recent invocations
   - Errors/exceptions

**Use Cases:**
- CD pipeline failed - need to debug
- Lambda throwing errors
- SAM deployment issues
- CloudFormation stack failed

**Output:** Detailed logs with timestamps and error messages

---

### 93-start-jenkins-ec2.sh

**Purpose:** Start stopped EC2 Jenkins instance

**Usage:**
```bash
./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --demo
./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --prod
```

**What it does:**
1. Finds stopped Jenkins EC2 instance by tags
2. Starts the instance
3. Waits for instance to be running
4. Gets new public IP (may change)
5. Displays new Jenkins URL

**Duration:** ~1 minute

**Cost Savings:** Use this after stopping EC2 to save ~$15/month

**Note:** Public IP may change after stop/start

---

### 94-stop-jenkins-ec2.sh

**Purpose:** Stop EC2 Jenkins instance to save costs

**Usage:**
```bash
./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --demo
./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --prod
```

**What it does:**
1. Finds running Jenkins EC2 instance
2. Confirms stop action
3. Stops the instance
4. Waits for instance to stop

**Cost Savings:**
- Running 24/7: ~$15/month
- Stopped: ~$3/month (EBS storage only)
- Savings: ~$12/month

**Use When:** Not actively developing (evenings, weekends)

**Note:** Jenkins data persists (EBS volume)

---

### 99-cleanup-all.sh

**Purpose:** Delete all AWS resources

**Usage:**
```bash
./scripts/aws-ci-cd/99-cleanup-all.sh --demo
./scripts/aws-ci-cd/99-cleanup-all.sh --prod
```

**What it deletes:**
1. CloudFormation stack (Lambda, API Gateway, IAM roles, logs)
2. ECR repository and all images
3. SAM deployment bucket
4. EC2 Jenkins instance (if exists)
5. Security groups (if created by scripts)

**Confirmation:** Required (type 'yes')

**Warnings:**
- ⚠️ DESTRUCTIVE and IRREVERSIBLE
- All data will be deleted
- Cannot be undone
- Stops automated CI/CD (if EC2 deleted)

**Use Cases:**
- Done with AWS Learner Lab session
- Want to start fresh
- Avoid AWS costs
- Clean up after testing

**Duration:** ~2-5 minutes

**Verification:** Script checks all resources deleted

---

## Common Workflows

### First-Time Setup (Complete)

```bash
# Phase 1-2: Infrastructure
./scripts/aws-ci-cd/10-check-prerequisites.sh
./scripts/aws-ci-cd/11-setup-ecr.sh

# Phase 3: Manual SAM Validation (CRITICAL GATE)
./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo
./scripts/aws-ci-cd/30-cd-validate-sam.sh --demo
./scripts/aws-ci-cd/31-cd-deploy-sam.sh --demo
./scripts/aws-ci-cd/32-cd-verify-deployment.sh --demo

# If all above succeed, proceed:

# Phase 4: Jenkins EC2 Automation
./scripts/aws-ci-cd/12-setup-jenkins-ec2.sh --demo
./scripts/aws-ci-cd/13-configure-jenkins-jobs.sh --demo

# Now: git push triggers full CI/CD automatically!
```

### Daily Development

```bash
# Normal workflow: Just push to GitHub
git push origin Jeffery

# Jenkins EC2 automatically:
# 1. Runs CI job (test, build, push to ECR)
# 2. Runs CD job (deploy to Lambda)
# 3. Verifies deployment

# Check status
./scripts/aws-ci-cd/90-check-aws-status.sh --demo
```

### Troubleshooting Failed CD

```bash
# View logs to find error
./scripts/aws-ci-cd/92-view-cd-logs.sh --demo

# If issue is in SAM template:
# 1. Fix template.yaml locally
# 2. Redeploy without rebuilding
./scripts/aws-ci-cd/33-cd-redeploy-image.sh --demo --image-tag jeffery-42

# If new deployment has bugs:
./scripts/aws-ci-cd/34-cd-rollback.sh --demo
```

### Cost Management

```bash
# End of day: Stop Jenkins to save costs
./scripts/aws-ci-cd/94-stop-jenkins-ec2.sh --demo

# Next morning: Start Jenkins
./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --demo

# End of week: Clean up everything
./scripts/aws-ci-cd/99-cleanup-all.sh --demo
```

---

## Error Messages and Solutions

### "Error: Backend not specified"

**Cause:** Script requires `--demo` or `--prod` flag

**Solution:** Add flag: `./script.sh --demo`

---

### "ECR repository not found"

**Cause:** ECR repository hasn't been created

**Solution:** Run `./scripts/aws-ci-cd/11-setup-ecr.sh`

---

### "No images in ECR"

**Cause:** Haven't pushed any Docker images yet

**Solution:** Run `./scripts/aws-ci-cd/20-ci-build-and-push.sh --demo`

---

### "IAM CreateRole permission denied"

**Cause:** AWS Learner Lab blocks IAM role creation

**Solution:** Ensure `template.yaml` uses LabRole (should be fixed in Phase 3)

---

### "Jenkins not accessible"

**Cause:** EC2 instance stopped or security group issue

**Solution:**
1. Check instance: `./scripts/aws-ci-cd/91-check-jenkins-status.sh --demo`
2. If stopped: `./scripts/aws-ci-cd/93-start-jenkins-ec2.sh --demo`
3. Check security group allows port 8080

---

### "Image tag not found in ECR"

**Cause:** Specified image tag doesn't exist

**Solution:**
1. List images: `aws ecr list-images --repository-name aws-lab-flask-demo`
2. Use existing tag or build new image

---

## Best Practices

1. **Always validate SAM manually first** (Phase 3) before Jenkins automation
2. **Use `--demo` for testing**, `--prod` for releases
3. **Stop EC2 when not in use** to save costs (~$12/month savings)
4. **Check status regularly** to monitor resources and costs
5. **Clean up after testing** to avoid unnecessary charges
6. **Test rollback** before you need it in production
7. **Review logs** when deployments fail - they show the error
8. **Keep ECR images tagged** - untagged images deleted after 1 day

---

## Additional Resources

- **Main Documentation:** `README.md`
- **Development Diary:** `DEVELOPMENT_DIARY.md` (Phase 7)
- **Branch Strategy:** `BRANCH_STRATEGY.md`
- **Architecture Details:** `CLAUDE.md`
- **Task Breakdown:** `specs/001-aws-lab-flask-ci-cd-demo/aws-lab-flask-tasks.md`
- **Validation Checklist:** `specs/001-aws-lab-flask-ci-cd-demo/aws-lab-flask-checklist.md`
