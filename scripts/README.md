# Automation Scripts

This directory contains scripts for local testing and AWS deployment automation.

## Directory Structure

```
scripts/
├── local/              # Local development & testing (CI only)
│   ├── setup-jenkins.sh
│   ├── build-local.sh
│   └── test-local.sh
│
└── aws/                # AWS deployment automation (CD)
    ├── 01-check-prerequisites.sh
    ├── 02-setup-ecr.sh
    ├── 03-build-and-push.sh
    ├── 04-deploy-sam.sh
    ├── 05-verify-deployment.sh
    ├── 99-cleanup-all.sh
    └── check-aws-status.sh
```

## Local Scripts (Development & CI)

### setup-jenkins.sh
**Purpose:** Set up Jenkins container for local CI testing

**Usage:**
```bash
./scripts/local/setup-jenkins.sh
```

**What it does:**
- Starts Jenkins Docker container
- Installs Python and Docker CLI in container
- Configures Docker socket permissions
- Displays admin password and access info

**When to use:** First-time Jenkins setup or after deleting container

---

### build-local.sh
**Purpose:** Build Docker image locally (without AWS)

**Usage:**
```bash
./scripts/local/build-local.sh
```

**What it does:**
- Optionally runs tests first
- Builds Docker image from Dockerfile
- Tags image as `aws-lab-flask-demo:local`
- Verifies build succeeded

**When to use:** Test Docker build before pushing to AWS

---

### test-local.sh
**Purpose:** Run pytest test suite locally

**Usage:**
```bash
./scripts/local/test-local.sh
```

**What it does:**
- Sets up Python virtual environment
- Runs all unit and integration tests
- Displays test results

**When to use:** Before committing code or pushing to repository

---

## AWS Scripts (Deployment & CD)

### 01-check-prerequisites.sh
**Purpose:** Verify AWS environment is ready for deployment

**Usage:**
```bash
./scripts/aws/01-check-prerequisites.sh
```

**What it checks:**
- AWS CLI installed and configured
- Valid AWS credentials (Learner Lab)
- SAM CLI installed
- Docker running
- Correct AWS region (us-east-1)

**When to use:** FIRST before any AWS deployment

---

### 02-setup-ecr.sh
**Purpose:** Create AWS ECR repository

**Usage:**
```bash
./scripts/aws/02-setup-ecr.sh
```

**What it does:**
- Creates ECR repository (if doesn't exist)
- Enables image scanning
- Saves repository URI to .env file

**When to use:** Once per project (idempotent - safe to run multiple times)

---

### 03-build-and-push.sh
**Purpose:** Build Docker image and push to ECR

**Usage:**
```bash
./scripts/aws/03-build-and-push.sh
```

**What it does:**
- Optionally runs tests first
- Builds Docker image
- Authenticates Docker to ECR
- Tags image with ECR URI
- Pushes image to AWS
- Verifies upload succeeded

**When to use:** Every time you update code and want to deploy

---

### 04-deploy-sam.sh
**Purpose:** Deploy application to AWS Lambda

**Usage:**
```bash
./scripts/aws/04-deploy-sam.sh
```

**What it does:**
- Updates SAM configuration with ECR URI
- Validates SAM template
- Builds SAM application
- Deploys to AWS (creates Lambda, API Gateway, IAM roles)
- Displays API endpoints and outputs

**When to use:** After pushing image to ECR

---

### 05-verify-deployment.sh
**Purpose:** Test and verify AWS deployment

**Usage:**
```bash
./scripts/aws/05-verify-deployment.sh
```

**What it does:**
- Tests /health endpoint (3x - success criteria)
- Tests /echo endpoint with JSON
- Checks Lambda function configuration
- Views CloudWatch logs
- Validates all success criteria

**When to use:** After deployment to verify everything works

---

### check-aws-status.sh
**Purpose:** Display current status of all AWS resources

**Usage:**
```bash
./scripts/aws/check-aws-status.sh
```

**What it shows:**
- ECR repository and images
- CloudFormation stack status
- Lambda function details
- API Gateway URLs
- CloudWatch log groups
- Estimated monthly costs

**When to use:** Anytime to see what's deployed

---

### 99-cleanup-all.sh
**Purpose:** Delete ALL AWS resources

**Usage:**
```bash
./scripts/aws/99-cleanup-all.sh
```

**What it deletes:**
- CloudFormation stack (Lambda, API Gateway, IAM)
- ECR repository and all images
- SAM deployment bucket

**⚠️  WARNING:** This is DESTRUCTIVE and IRREVERSIBLE!

**When to use:** When done with project to free up Learner Lab budget

---

## Typical Workflows

### First-Time Setup
```bash
# 1. Set up local Jenkins (one-time)
./scripts/local/setup-jenkins.sh

# 2. Verify AWS environment
./scripts/aws/01-check-prerequisites.sh

# 3. Create ECR repository (one-time)
./scripts/aws/02-setup-ecr.sh
```

### Development Workflow (Local CI)
```bash
# 1. Make code changes

# 2. Test locally
./scripts/local/test-local.sh

# 3. Build locally (optional)
./scripts/local/build-local.sh

# 4. Push to Jeffery branch (triggers Jenkins CI)
git add .
git commit -m "feat: your changes"
git push origin Jeffery
```

### Deployment Workflow (Manual)
```bash
# 1. Build and push to ECR
./scripts/aws/03-build-and-push.sh

# 2. Deploy to AWS
./scripts/aws/04-deploy-sam.sh

# 3. Verify deployment
./scripts/aws/05-verify-deployment.sh

# 4. Check status anytime
./scripts/aws/check-aws-status.sh
```

### Full CI/CD Workflow (Automated)
```bash
# 1. Develop on Jeffery branch (CI only)
git checkout Jeffery
# ... make changes ...
git push origin Jeffery  # Triggers Jenkins: test + build only

# 2. Merge to main (full CI/CD)
git checkout main
git merge Jeffery
git push origin main  # Triggers Jenkins: test + build + deploy to AWS
```

### Cleanup
```bash
# Delete all AWS resources
./scripts/aws/99-cleanup-all.sh
```

---

## Script Features

All scripts include:
- ✅ Detailed command explanations
- ✅ Color-coded output (green=success, red=error, yellow=warning)
- ✅ Error handling with helpful messages
- ✅ Idempotent (safe to run multiple times)
- ✅ Educational comments (learn AWS CLI commands)

---

## Learning Resources

Each script teaches you AWS CLI commands by:
1. Showing the exact command
2. Explaining what each parameter does
3. Describing what happens behind the scenes
4. Providing examples of expected output

Read the scripts to understand:
- How ECR authentication works
- How Docker images are tagged and pushed
- How SAM/CloudFormation deploys infrastructure
- How to read CloudWatch logs
- How to check resource status

---

## Troubleshooting

### "AWS credentials not configured"
- **Solution:** Run `./scripts/aws/01-check-prerequisites.sh` for detailed instructions
- For Learner Lab: Copy credentials from AWS Details panel

### "ECR repository not found"
- **Solution:** Run `./scripts/aws/02-setup-ecr.sh` first

### "Image not found in ECR"
- **Solution:** Run `./scripts/aws/03-build-and-push.sh` to upload image

### "Tests failed"
- **Solution:** Fix code issues, then run `./scripts/local/test-local.sh` again

### "Docker not running"
- **Solution:** Start Docker Desktop

For more help, see:
- `AWS_DEPLOYMENT_GUIDE.md` - Comprehensive deployment guide
- `TROUBLESHOOTING.md` - Common issues and solutions
- Each script's comments - Inline documentation

---

## Contributing

When adding new scripts:
1. Follow the naming convention (numbered for AWS scripts)
2. Include detailed comments explaining commands
3. Add color-coded output for better UX
4. Make scripts idempotent
5. Add error handling
6. Update this README with usage instructions
