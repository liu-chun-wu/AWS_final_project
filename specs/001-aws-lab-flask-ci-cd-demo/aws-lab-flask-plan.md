# Implementation Plan: AWS Learner Lab Flask CI/CD Demo

**Branch**: `[001-aws-lab-flask-ci-cd-demo]` | **Date**: 2025-11-21 | **Spec**: `specs/001-aws-lab-flask-ci-cd-demo/spec.md`

**Input**: Feature specification from `/specs/001-aws-lab-flask-ci-cd-demo/spec.md`

## Summary

Implement a small Flask-based demo backend with `GET /health` and `POST /echo` endpoints, containerize it with Docker, and create a Jenkins pipeline that can run locally and later on an EC2 instance in AWS Learner Lab. For the AWS phase, reuse the same Docker image via Amazon ECR as an AWS Lambda container behind API Gateway, with logs and basic metrics flowing into CloudWatch.

## Technical Context

**Language/Version**: Python 3.11  
**Primary Dependencies**: Flask 3.x, gunicorn (for production/container entrypoint), pytest (tests)  
**Storage**: None (stateless demo service; no database required)  
**Testing**: pytest + Flask test client, optional integration tests using `requests`  
**Target Platform**: Local development machine (macOS / Linux / WSL), Docker, AWS Lambda (container images), AWS EC2 (for Jenkins)  
**Project Type**: Web backend (no frontend for this feature)  
**Performance Goals**: Support basic demo load (~20 req/s) with p95 latency under 500 ms  
**Constraints**:  

- Must run within AWS Learner Lab service and quota limits  
- Keep Lambda memory size modest (e.g., 256–512 MB)  
- Minimize external services to reduce complexity and cost  
**Scale/Scope**: Single-team student project; focus on CI/CD learning rather than high traffic

## Constitution Check

- The project uses a single backend service with one CI/CD pipeline.
- No database or complex domain modeling is required.
- AWS usage is limited to services available inside Learner Lab: ECR, Lambda, API Gateway, EC2, CloudWatch, IAM.

Result: No major complexity violations. The architecture remains intentionally small and focused on CI/CD patterns.

## Project Structure

### Documentation (this feature)

```text
specs/001-aws-lab-flask-ci-cd-demo/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # (optional) Notes on Flask, Lambda containers, Jenkins
├── data-model.md        # (minimal or N/A, no DB)
├── quickstart.md        # (optional) High-level "do this first" guide
├── contracts/           # (optional) HTTP contract examples
└── tasks.md             # Execution tasks list
```

### Code Structure

```text
aws-lab-flask-ci-cd/
├── backend/
│   ├── src/
│   │   └── app.py              # Flask app with /health and /echo
│   ├── tests/
│   │   ├── unit/               # Flask test client tests
│   │   └── integration/        # Full HTTP tests
│   ├── requirements.txt        # Flask, gunicorn, pytest
│   ├── Dockerfile              # Lambda-compatible container
│   └── .dockerignore
├── ci/
│   ├── Jenkinsfile-CI          # CI job: Test → Build → Push to ECR
│   └── Jenkinsfile-CD          # CD job: Deploy SAM → Verify
├── aws/
│   ├── template.yaml           # SAM template (Lambda + API Gateway)
│   ├── samconfig-demo.toml     # Demo backend config
│   └── samconfig-prod.toml     # Production backend config
├── scripts/
│   ├── local-ci-only/          # Local CI scripts (no AWS deployment)
│   │   ├── setup-jenkins.sh
│   │   ├── test-local.sh
│   │   └── build-local.sh
│   └── aws-ci-cd/              # Full CI/CD scripts for AWS
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
├── docs/
│   ├── SCRIPT_GUIDE.md         # Detailed script reference
│   └── JENKINS_EC2_SETUP.md    # Jenkins on EC2 guide
├── .gitignore
├── README.md
├── CLAUDE.md
├── BRANCH_STRATEGY.md
├── DEVELOPMENT_DIARY.md
└── VALIDATION.md
```

## Implementation Phases

### Updated Phase Structure (Phase 8 Refinement)

**Key Philosophy: Prove → Codify → Automate**

Test each step manually BEFORE automating with Jenkins. This reduces risk, speeds debugging, and ensures Jenkins deploys with complete, proven configurations.

---

**Phase 1: Local Flask Application**
- Create basic Flask REST API
- Implement `/health` endpoint (GET)
- Implement `/echo` endpoint (POST)
- Write pytest test suite (unit + integration)
- Local development with Flask dev server
- Validate: All tests passing

**Phase 2: Docker Containerization**
- Create Dockerfile with Lambda-compatible runtime
- Use gunicorn as WSGI server (not Flask dev server)
- Multi-stage build for optimization
- Test container locally
- Validate: Container runs identically to local Flask

**Phase 3a: Manual CI Testing - Build & Push** *(Critical Gate Part 1)*
- Setup ECR repository (aws-lab-flask-demo)
- Run tests locally: `pytest backend/tests -v`
- Build Docker image manually
- Tag image: `<ECR-URI>:manual-test`
- Push to ECR using AWS CLI
- **Rationale**: Proves CI operations work BEFORE Jenkins automation
- Validate: Image in ECR, tests pass

**Phase 3b: Manual CD Testing - Deploy & Verify** *(Critical Gate Part 2)*
- Validate SAM template syntax (`sam validate`)
- Fix IAM permissions (use LabRole)
- Build SAM: `sam build --use-container`
- Deploy to Lambda manually: `sam deploy --config-file samconfig-demo.toml`
- Test health endpoint: `curl <API-URL>/health`
- Test echo endpoint: `curl -X POST <API-URL>/echo`
- **Rationale**: Proves CD operations work BEFORE Jenkins automation
- **GATE: Both 3a AND 3b must succeed before Phase 4**
- Validate: Lambda responding, API Gateway working

**Phase 4: Jenkinsfile Preparation** *(NEW - Define Before Deploy)*
- Create `ci/Jenkinsfile-CI` locally
  - Stages: Checkout → Test → Build → Push to ECR
  - Parameters: BACKEND_DIR, BRANCH_NAME
  - Mirrors Phase 3a manual steps
- Create `ci/Jenkinsfile-CD` locally
  - Stages: Validate Image → Deploy SAM → Verify Health
  - Parameters: IMAGE_TAG, BACKEND_TYPE
  - Mirrors Phase 3b manual steps
- Commit both Jenkinsfiles to Git
- **Rationale**: Define pipelines as code BEFORE Jenkins deployment
- **Benefit**: Jenkins pulls complete configs from Git (no manual configuration in UI)
- Validate: Jenkinsfiles in Git repository

**Phase 5: Jenkins EC2 Deployment** *(Deploy AFTER Manual Validation)*
- Provision EC2 instance (t2.small, Amazon Linux 2023)
- Install: Java 17, Jenkins LTS, Docker, AWS CLI v2, SAM CLI, Git
- Configure IAM (use existing LabRole via instance profile)
- Setup security group (SSH 22, Jenkins 8080, HTTPS 443)
- Create Jenkins jobs pointing to Git Jenkinsfiles:
  - `flask-ci` → uses `ci/Jenkinsfile-CI`
  - `flask-cd` → uses `ci/Jenkinsfile-CD`
- **Rationale**: Deploy Jenkins ONCE with complete configuration
- **Benefit**: No deploy → debug → modify cycles
- Validate: Jenkins accessible, jobs configured from Git

**Phase 6: Jenkins Pipeline Testing** *(Test Automation Separately)*
- Test CI pipeline manually in Jenkins:
  - Trigger `flask-ci` job
  - Verify: Test → Build → Push works (same as Phase 3a)
- Test CD pipeline manually in Jenkins:
  - Trigger `flask-cd` job with IMAGE_TAG parameter
  - Verify: Validate → Deploy → Verify works (same as Phase 3b)
- Test CI→CD trigger:
  - Verify: CI success automatically triggers CD
  - Verify: Correct IMAGE_TAG passed to CD
- **Rationale**: Validate Jenkins automates proven steps
- **Benefit**: Higher confidence (we already know manual steps work!)
- Validate: Both pipelines green, automation working

**Phase 7: End-to-End Automation** *(Webhook Integration)*
- Configure GitHub webhook (points to EC2 Jenkins)
- Test Jeffery branch automation:
  - Push code → CI → CD → demo-backend
- Test main branch automation:
  - Push code → CI → CD → prod-backend
- Branch-based routing validated
- **Rationale**: Full automation as final step (not first step)
- Validate: Push to Git triggers complete CI/CD flow

**Phase 8: Recovery Scripts** *(Optional/Utility)*
- Rollback script (`34-cd-rollback.sh`): Deploy previous image
- Redeploy script (`33-cd-redeploy-image.sh`): Deploy existing image
- Monitoring scripts: Jenkins status, CD logs, EC2 start/stop
- **Rationale**: Operational safety and cost management
- Validate: Can restore service in <3 minutes

### Script Organization Philosophy

**Grouped Numbering System:**

```
10-19: Infrastructure Setup (one-time operations)
  - Run once during initial setup
  - Create foundational AWS resources
  - Configure EC2 Jenkins instance

20-29: CI Operations (build, test, push)
  - Continuous Integration workflows
  - Can run repeatedly during development
  - Manual fallbacks for Jenkins

30-39: CD Operations (deploy, verify, rollback)
  - Continuous Deployment workflows
  - SAM validation and deployment
  - Recovery and rollback capabilities

90-99: Utilities and Cleanup
  - Monitoring and status checks
  - Cost management (start/stop EC2)
  - Resource cleanup
```

**Folder Naming Convention:**

```
scripts/local-ci-only/    Explicit: CI testing without AWS
scripts/aws-ci-cd/        Explicit: Full CI/CD pipeline in AWS
```

Benefits:
- **Self-documenting**: Number indicates purpose
- **Easy to find**: Looking for deployment? Check 30s
- **Scalable**: Can add scripts without renumbering
- **Professional**: Industry standard (systemd, init.d)

### CI/CD Separation Rationale

**Why Two Jenkins Jobs Instead of One Pipeline:**

**Problem with Monolithic Pipeline:**
- If deployment fails (SAM config error), must rebuild entire Docker image
- Can't deploy previous image version (no rollback)
- Can't tell if failure is in CI (build) or CD (deploy)
- Wastes time re-running passing tests for config fixes

**Benefits of Separation:**
1. **Failure Isolation**: Know immediately if CI or CD failed
2. **Independent Retry**: Re-run CD without rebuilding image
3. **Rollback Capability**: Deploy any previous ECR image tag
4. **Time Savings**: Don't re-run 5-minute builds for config fixes
5. **Better Debugging**: Separate logs for build vs deploy
6. **Flexibility**: Can disable CD while keeping CI active

**Industry Precedent:**
- Google Cloud Build: Separate builder + deployer
- AWS CodePipeline: Source → Build → Deploy as separate stages
- GitLab CI: Separate jobs with dependencies

**Implementation:**
```groovy
// Jenkinsfile-CI (last stage)
post {
    success {
        build job: 'flask-cd', parameters: [
            string(name: 'IMAGE_TAG', value: "${IMAGE_TAG}"),
            string(name: 'BACKEND_TYPE', value: "${env.BACKEND_TYPE}")
        ], wait: false
    }
}
```

### Manual Validation Before Automation

**Why Phase 3 (Manual SAM Validation) is Critical:**

**Without Manual Validation:**
```
Setup Jenkins → Configure → Push code → Jenkins deploys → Fails
                                                            ↓
                                            Debug through Jenkins complexity
                                                            ↓
                                            Fix, re-trigger, wait 5+ minutes
```

**With Manual Validation:**
```
Build manually → Deploy SAM manually → Works in 30 seconds
                                        ↓
                        Proven deployment path
                                        ↓
                        Jenkins succeeds first try
```

**Real-World Impact:**
During this project, we hit IAM permission errors. Manual validation found the issue in 5 minutes. If this happened in Jenkins first, would need to:
- SSH into EC2
- Debug Jenkins logs
- Fix template
- Re-trigger pipeline
- Wait for full rebuild

**Time Savings:** 15-25 minutes per config iteration

## Risk Assessment

**High Risk:**
1. **AWS Learner Lab IAM Restrictions**
   - Risk: Can't create IAM roles
   - Mitigation: Use existing LabRole for all resources
   - Status: ✅ Mitigated

2. **ECR Image Size**
   - Risk: Large images slow deployment
   - Mitigation: Multi-stage builds, .dockerignore
   - Status: ✅ Mitigated (~250MB compressed)

**Medium Risk:**
1. **Jenkins EC2 Costs**
   - Risk: $15-20/month if always running
   - Mitigation: Start/stop scripts provided
   - Status: ✅ Mitigated (scripts created)

2. **SAM Deployment Failures**
   - Risk: CloudFormation errors hard to debug
   - Mitigation: Manual validation phase before automation
   - Status: ✅ Mitigated (Phase 3 gate)

**Low Risk:**
1. **GitHub Webhook Reliability**
   - Risk: Webhook might not reach EC2
   - Mitigation: Security group allows inbound, manual trigger available
   - Status: ✅ Acceptable

## Cost Analysis

**AWS Resources Monthly Costs:**

```
EC2 Jenkins Instance (t2.small):
  - Running 24/7:    ~$15/month
  - Running 8hr/day: ~$5/month
  - Stopped:         ~$3/month (EBS only)

ECR Repository:
  - 10 images × 250MB: ~$0.03/month

Lambda:
  - Free tier: 1M requests/month
  - Demo usage: ~100 requests/month
  - Cost: $0

API Gateway:
  - Free tier: 1M requests/month
  - Demo usage: ~100 requests/month
  - Cost: $0

CloudWatch Logs:
  - Free tier: 5GB ingestion/month
  - Demo usage: ~100MB/month
  - Cost: $0

Total Estimated Cost:
  - Always-on Jenkins: ~$18/month
  - Start/stop Jenkins: ~$8/month
  - Learner Lab: Well within budget
```

**Cost Management Strategies:**
1. Use `94-stop-jenkins-ec2.sh` when not developing
2. ECR lifecycle policy to delete old images
3. Lambda free tier covers demo usage
4. CloudWatch Logs retention: 7 days

## Prerequisites

**Local Development:**
- Python 3.11 (not 3.12+ due to Lambda compatibility)
- Docker Desktop
- Git
- Conda (recommended for environment management)

**AWS Learner Lab:**
- Active Learner Lab session
- AWS CLI configured with credentials
- Access to: EC2, ECR, Lambda, API Gateway, CloudWatch, IAM (read-only)

**Optional:**
- Jenkins running locally (for local CI testing)
- ngrok (for local webhook testing)

## Dependencies

**Python Dependencies:**
```
Flask 3.x          # REST API framework
gunicorn           # WSGI server for production
pytest             # Testing framework
requests           # HTTP client (integration tests)
```

**AWS Services:**
```
ECR                # Docker image registry
Lambda             # Serverless compute
API Gateway        # HTTP API endpoint
CloudWatch Logs    # Log aggregation
EC2                # Jenkins server
IAM                # Permissions (read-only)
CloudFormation     # Infrastructure deployment (via SAM)
```

**Development Tools:**
```
Docker             # Containerization
AWS CLI v2         # AWS operations
SAM CLI            # Serverless deployment
Jenkins            # CI/CD orchestration
Git                # Version control
```

## Success Criteria

1. **Functional:**
   - ✅ Flask app runs locally
   - ✅ Docker container works identically to local
   - ✅ All tests pass (18/18)
   - ✅ Lambda responds to API Gateway requests
   - ✅ CI/CD fully automated

2. **Performance:**
   - ✅ Build time < 5 minutes
   - ✅ Deploy time < 4 minutes
   - ✅ API latency < 500ms (p95)

3. **Reliability:**
   - ✅ Rollback capability works
   - ✅ Manual fallback scripts available
   - ✅ Clear error messages

4. **Educational:**
   - ✅ Every script self-documenting
   - ✅ Complete documentation
   - ✅ Clear workflow examples

5. **Cost:**
   - ✅ Within Learner Lab budget
   - ✅ Cost management tools provided
   - ✅ All resources cleanable

## Timeline Estimate

- Phase 1 (Local Flask): 4-6 hours
- Phase 2 (Docker): 3-4 hours
- Phase 3 (Manual SAM): 4-6 hours
- Phase 4 (Jenkins EC2): 8-10 hours
- Phase 5 (Automation): 4-6 hours
- Phase 6 (Documentation): 6-8 hours

**Total:** ~30-40 hours (actual: 40 hours over 18 days)

## Notes

- **Educational Focus**: This project prioritizes learning over production scale
- **Manual Validation**: Phase 3 is critical gate before automation
- **Cost Conscious**: Designed for AWS Learner Lab constraints
- **Flexibility**: Both automated (Jenkins) and manual (scripts) paths
- **Industry Patterns**: Follows real-world CI/CD best practices
