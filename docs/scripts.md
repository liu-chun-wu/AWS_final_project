# Scripts Reference

Complete reference for all automation scripts in the project.

## Table of Contents

- [Organization](#organization)
- [Local Scripts](#local-scripts)
- [Jenkins/AWS Scripts](#jenkinsaws-scripts)
- [Usage Examples](#usage-examples)

---

## Organization

Scripts are split into two folders:

| Folder | Purpose | AWS Access |
|--------|---------|------------|
| `scripts/local/` | Local smoke tests | No |
| `scripts/jenkins/` | CI/CD automation | Yes |

### Numbering Convention

| Range | Purpose |
|-------|---------|
| 11-19 | Infrastructure setup |
| 20-29 | CI operations |
| 30-39 | CD operations |
| 40-49 | Jenkins setup |
| 91-99 | Utilities |

---

## Local Scripts

Located in `scripts/local/` - never touch AWS.

### test-local.sh

Run pytest test suite locally.

```bash
# Syntax
./scripts/local/test-local.sh --prod|--demo

# Examples
./scripts/local/test-local.sh --prod   # Test production backend
./scripts/local/test-local.sh --demo   # Test demo backend
```

**What it does:**
1. Validates arguments
2. Checks Python 3 is available
3. Creates/activates virtual environment
4. Installs dependencies (first run)
5. Runs pytest with verbose output

---

### build-local.sh

Build Docker image locally (no push).

```bash
# Syntax
./scripts/local/build-local.sh --prod|--demo

# Examples
./scripts/local/build-local.sh --prod   # Build production backend
./scripts/local/build-local.sh --demo   # Build demo backend
```

**What it does:**
1. Validates arguments
2. Builds Docker image with `--platform linux/amd64`
3. Tags as `aws-lab-flask-demo:local`

---

## Jenkins/AWS Scripts

Located in `scripts/jenkins/` - interact with AWS services.

### Infrastructure Setup (11-19)

#### 11-setup-ecr.sh

Create or validate ECR repository.

```bash
./scripts/jenkins/11-setup-ecr.sh
```

**What it does:**
1. Checks if repository exists
2. Creates repository if needed
3. Enables image scanning
4. Outputs repository URI

---

### CI Operations (20-29)

#### 20-ci-build-and-push.sh

Full CI: test ’ build ’ push to ECR.

```bash
# Syntax
./scripts/jenkins/20-ci-build-and-push.sh --prod|--demo [--image-tag TAG]

# Examples
./scripts/jenkins/20-ci-build-and-push.sh --prod
./scripts/jenkins/20-ci-build-and-push.sh --demo --image-tag v1.0.0
```

**What it does:**
1. Runs pytest tests
2. Builds Docker image (linux/amd64)
3. Authenticates to ECR
4. Ensures ECR repository exists
5. Tags image (build tag + latest)
6. Pushes to ECR
7. Verifies push

---

### CD Operations (30-39)

#### 30-cd-validate-sam.sh

Validate SAM template before deployment.

```bash
./scripts/jenkins/30-cd-validate-sam.sh --prod|--demo
```

**What it does:**
1. Runs `sam validate` on template
2. Checks LabRole exists
3. Verifies SAM configuration

---

#### 31-cd-deploy-sam.sh

Deploy to Lambda via SAM.

```bash
# Syntax
./scripts/jenkins/31-cd-deploy-sam.sh --prod|--demo [--image-tag TAG]

# Examples
./scripts/jenkins/31-cd-deploy-sam.sh --prod
./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag jenkins-42
```

**What it does:**
1. Selects correct SAM config (demo or prod)
2. Resolves AWS account ID
3. Sets ImageTag parameter
4. Runs `sam deploy`
5. Outputs API Gateway URL

---

#### 32-cd-verify-deployment.sh

Test deployed endpoints.

```bash
./scripts/jenkins/32-cd-verify-deployment.sh --prod|--demo
```

**What it does:**
1. Gets API URL from SAM outputs
2. Tests `/health` endpoint
3. Tests `/echo` endpoint
4. Reports success/failure

---

### Jenkins Setup (40-49)

#### 40-setup-jenkins-local.sh

Start Jenkins in Docker for local testing.

```bash
./scripts/jenkins/40-setup-jenkins-local.sh
```

**What it does:**
1. Pulls Jenkins LTS image
2. Starts container with port 8080, Docker socket, and repo mounted
3. Outputs initial admin password

---

#### 41-setup-jenkins-ec2.sh

Provision Jenkins on EC2.

```bash
./scripts/jenkins/41-setup-jenkins-ec2.sh --prod|--demo
```

**What it does:**
1. Creates security group (ports 22, 8080)
2. Launches EC2 instance (default t3.medium)
3. Installs Docker, Jenkins, SAM CLI
4. Attaches LabRole instance profile
5. Outputs connection info and admin password

---

#### 42-configure-jenkins-jobs.sh

Create CI/CD jobs in Jenkins.

```bash
./scripts/jenkins/42-configure-jenkins-jobs.sh --local|--ec2 --prod|--demo
```

**What it does:**
1. Installs required plugins
2. Creates `flask-ci` and `flask-cd` jobs
3. Configures SCM to pull Jenkinsfiles from Git

---

### Utilities (91-99)

#### 91-check-jenkins-status.sh

Check EC2 Jenkins status.

```bash
./scripts/jenkins/91-check-jenkins-status.sh
```

---

#### 93-start-jenkins-ec2.sh

Start stopped EC2 Jenkins instance.

```bash
./scripts/jenkins/93-start-jenkins-ec2.sh
```

---

#### 94-stop-jenkins-ec2.sh

Stop EC2 Jenkins instance (save costs).

```bash
./scripts/jenkins/94-stop-jenkins-ec2.sh
```

---

#### 99-cleanup-all.sh

Delete all AWS resources.

```bash
./scripts/jenkins/99-cleanup-all.sh
```

---

## Usage Examples

### First-Time Setup

```bash
./scripts/local/test-local.sh --prod
./scripts/local/build-local.sh --prod
./scripts/jenkins/11-setup-ecr.sh
./scripts/jenkins/20-ci-build-and-push.sh --prod
./scripts/jenkins/31-cd-deploy-sam.sh --prod
./scripts/jenkins/32-cd-verify-deployment.sh --prod
```

### Daily Development

```bash
./scripts/local/test-local.sh --prod
git add . && git commit -m "feat: new feature"
git push origin Jeffery
```

### Cost Management

```bash
./scripts/jenkins/94-stop-jenkins-ec2.sh  # Stop when done
./scripts/jenkins/93-start-jenkins-ec2.sh  # Start when needed
```

---

## See Also

- [CI/CD Pipeline](CI_CD.md)
- [Quick Start](QUICK_START.md)
- [Troubleshooting](TROUBLESHOOTING.md)
