# Team Collaboration Guide

Welcome! This guide will help you get started working on the production backend service.

## Table of Contents

- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [CI/CD Pipeline](#cicd-pipeline)
- [Deployment](#deployment)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- **Python 3.11** installed
- **Docker** Desktop running
- **Git** configured with your GitHub account
- **AWS CLI** (if deploying to AWS)
- **Access** to the repository

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd AWS_final_project
   ```

2. **Checkout the development branch:**
   ```bash
   git checkout Jeffery
   ```

3. **Set up Python environment:**
   ```bash
   cd backend
   python3.11 -m venv .venv
   source .venv/bin/activate  # macOS/Linux
   # OR .venv\Scripts\activate  # Windows
   pip install -r requirements.txt
   ```

4. **Verify setup:**
   ```bash
   # Run tests to ensure everything works
   cd ..
   ./scripts/local/test-local.sh
   ```

## Project Structure

### Directory Layout

```
AWS_final_project/
├── backend/              ← YOUR WORK GOES HERE
│   ├── src/             # Production service code
│   ├── tests/           # Your tests
│   ├── requirements.txt # Dependencies
│   └── Dockerfile       # Container config
│
├── demo-backend/        ← DO NOT MODIFY (CI/CD validation)
│   └── ...             # Flask demo for testing pipeline
│
├── ci/
│   └── Jenkinsfile     # CI/CD pipeline (review only)
│
├── scripts/
│   ├── local/          # Local development helpers
│   └── aws/            # AWS deployment automation
│
└── docs...             # Documentation
```

### What to Work On

**✅ DO modify:**
- `backend/src/` - Your production code
- `backend/tests/` - Your tests
- `backend/requirements.txt` - Dependencies you need
- `backend/Dockerfile` - Only if needed

**❌ DO NOT modify:**
- `demo-backend/` - Used for CI/CD validation
- `ci/Jenkinsfile` - Contact team lead for changes
- `scripts/` - Contact team lead for changes
- `aws/template.yaml` - Infrastructure is managed centrally

## Development Workflow

### Daily Development (Jeffery Branch)

This is where you do all your development work.

```bash
# 1. Start on Jeffery branch
git checkout Jeffery
git pull origin Jeffery

# 2. Make your changes in backend/src/
# ... edit files ...

# 3. Add tests in backend/tests/
# ... write tests ...

# 4. Test locally BEFORE committing
./scripts/local/test-local.sh

# 5. If tests pass, commit your changes
git add backend/
git commit -m "feat: describe your changes"

# 6. Push to Jeffery branch
git push origin Jeffery

# Jenkins will automatically:
# - Run all tests
# - Build Docker image
# - Show results in ~2 minutes
# - NOT deploy to AWS (development only)
```

### Checking Jenkins Build Status

After pushing to Jeffery:

1. Go to Jenkins: **http://localhost:8080/blue** (or your team's Jenkins URL)
2. Find your build in the pipeline view
3. Click to see stage-by-stage progress
4. If it fails, click the failed stage to see error details

### Production Deployment (Main Branch)

**⚠️ Only team leads merge to main**

When your feature is complete and tested:

```bash
# 1. Ensure Jeffery CI is green (all tests passing)
git push origin Jeffery
# Wait for Jenkins ✅ green build

# 2. Create a pull request (or notify team lead)
# DO NOT merge directly to main yourself

# 3. Team lead will:
#    - Review your code
#    - Merge to main
#    - Manually trigger the `flask-cd` job with the approved IMAGE_TAG to deploy
```

## Testing

### Running Tests Locally

```bash
# Run all tests for your backend
./scripts/local/test-local.sh

# Or manually:
cd backend
source .venv/bin/activate
pytest tests/ -v
```

### Writing Tests

Create tests in `backend/tests/`:

**Unit test example** (`backend/tests/unit/test_my_feature.py`):
```python
from src.app import app

def test_my_endpoint_returns_200():
    with app.test_client() as client:
        response = client.get('/my-endpoint')
        assert response.status_code == 200
```

**Integration test example** (`backend/tests/integration/test_my_flow.py`):
```python
import json
from src.app import app

def test_complete_workflow():
    with app.test_client() as client:
        # Test full request/response cycle
        response = client.post('/api/endpoint',
                             json={'data': 'test'},
                             content_type='application/json')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['result'] == 'expected'
```

### Test Requirements

- **All tests must pass** before pushing
- **Write tests for new features** (aim for good coverage)
- **Keep tests fast** (< 1 second per test ideally)
- **Use descriptive test names** (`test_user_login_with_valid_credentials`)

## CI/CD Pipeline

### Understanding the Pipeline

**Jeffery Branch (Development):**
```
Checkout → Setup → Install → Test → Build → ✅ Done
```
- **Duration:** ~1-2 minutes
- **Deployment:** None (CI only)
- **Cost:** $0
- **Purpose:** Fast feedback during development

**Main Branch (Production):**
```
Checkout → Setup → Install → Test → Build
    ↓
Login to ECR → Push to ECR → Deploy to Lambda → ✅ Done
```
- **Duration:** ~8 minutes
- **Deployment:** AWS Lambda + API Gateway
- **Cost:** ~$0.03-0.12/month
- **Purpose:** Production releases

### Pipeline Stages Explained

1. **Checkout** - Clone repository
2. **Branch Check** - Verify which branch and set mode
3. **Setup Python** - Create virtual environment
4. **Install Dependencies** - Install packages from requirements.txt
5. **Run Tests** - Execute pytest (pipeline fails if tests fail)
6. **Build Docker** - Create container image
7. **Login to ECR** *(main only)* - Authenticate to AWS
8. **Push to ECR** *(main only)* - Upload Docker image
9. **Deploy to Lambda** *(main only)* - Deploy via SAM

### Jenkins Parameters

When running builds manually, you can select:

- **BACKEND_DIR: demo-backend** - Test the CI/CD pipeline
- **BACKEND_DIR: backend** - Build/deploy production service

For regular development, just push to Jeffery and Jenkins auto-selects `backend`.

## Deployment

### Local Docker Testing

Before deploying, test your container locally:

```bash
# Build Docker image
./scripts/local/build-local.sh

# Run container
docker run --rm -p 8000:8000 aws-lab-flask-demo:local

# Test in another terminal
curl http://localhost:8000/health
```

### AWS Deployment (Team Lead Only)

After merging to main, deployment is automatic. To verify or redeploy manually:

```bash
# Redeploy a known image tag (optional)
./scripts/jenkins/31-cd-deploy-sam.sh --prod --image-tag main-42

# Smoke-test the deployed API
./scripts/jenkins/32-cd-verify-deployment.sh --prod
```

### Accessing Deployed Service

After deployment, Jenkins shows:
```
API Gateway URL: https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/
```

Test endpoints:
```bash
# Health check
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health

# Your endpoints
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/your-endpoint
```

### CloudWatch Logs

To view production logs:

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/flask-prod-backend-FlaskDemoFunction-xxx --follow

# View recent logs
aws logs tail /aws/lambda/flask-prod-backend-FlaskDemoFunction-xxx --since 1h
```

## Best Practices

### Code Quality

- ✅ **Write tests first** (TDD approach)
- ✅ **Keep functions small** (single responsibility)
- ✅ **Use type hints** (helps catch errors)
- ✅ **Add docstrings** (explain what functions do)
- ✅ **Follow PEP 8** (Python style guide)

### Git Workflow

- ✅ **Always work on Jeffery branch** for development
- ✅ **Pull before pushing** to avoid conflicts
- ✅ **Write descriptive commit messages**
  - Good: `feat: add user authentication endpoint`
  - Bad: `update file`, `fix bug`, `changes`
- ✅ **Commit frequently** (small, logical changes)
- ✅ **Never commit secrets** (API keys, passwords, etc.)

### Testing

- ✅ **Run tests before committing** every time
- ✅ **Fix failing tests immediately** (don't ignore)
- ✅ **Test edge cases** (empty input, invalid data, etc.)
- ✅ **Keep tests independent** (no dependencies between tests)

### Dependencies

- ✅ **Pin versions** in requirements.txt (`Flask==3.0.0`)
- ✅ **Test locally** after adding new dependencies
- ✅ **Minimize dependencies** (only add what you need)
- ✅ **Update requirements.txt**:
  ```bash
  pip install new-package
  pip freeze > requirements.txt
  git add requirements.txt
  ```

### Docker

- ✅ **Keep images small** (use multi-stage builds if needed)
- ✅ **Use .dockerignore** to exclude unnecessary files
- ✅ **Test locally** before pushing
- ✅ **One process per container** (Flask/gunicorn only)

## Troubleshooting

### Tests Fail Locally

```bash
# Run tests with verbose output to see what's failing
cd backend
source .venv/bin/activate
pytest tests/ -v --tb=short

# Run a specific test file
pytest tests/unit/test_feature.py -v

# Run a specific test
pytest tests/unit/test_feature.py::test_specific_function -v
```

### Jenkins Build Fails

1. **Check the stage that failed** in Blue Ocean
2. **Read the error message** carefully
3. **Common causes:**
   - Tests failing → Fix tests locally first
   - Dependency issues → Check requirements.txt
   - Docker build errors → Test `./scripts/local/build-local.sh`

### Import Errors

```bash
# Make sure virtual environment is activated
source backend/.venv/bin/activate

# Reinstall dependencies
pip install -r backend/requirements.txt

# Verify Flask is installed
pip list | grep Flask
```

### Port Already in Use

```bash
# Find what's using port 8000
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or use a different port
flask run --port 8001
```

### Git Conflicts

```bash
# If you have conflicts when pulling
git stash               # Save your changes
git pull origin Jeffery # Pull latest
git stash pop           # Reapply your changes
# Resolve conflicts manually
git add .
git commit
```

### Can't Run Scripts

```bash
# Make scripts executable
chmod +x scripts/local/*.sh
chmod +x scripts/jenkins/*.sh

# Then run
./scripts/local/test-local.sh
```

## Communication

### Getting Help

- **Slack/Teams:** #project-ci-cd channel
- **Email:** team-lead@example.com
- **Documentation:** See README.md, BRANCH_STRATEGY.md

### Reporting Issues

When reporting problems, include:

1. What you were trying to do
2. What you expected to happen
3. What actually happened
4. Error messages (copy/paste full output)
5. Steps to reproduce

**Good issue report:**
```
I tried to run tests but got an import error.

Expected: Tests run successfully
Actual: ImportError: No module named 'flask'

Error:
```
(paste full traceback)
```

Steps:
1. cd backend
2. source .venv/bin/activate
3. pytest tests/

Python version: 3.11.5
OS: macOS 14.0
```

## Quick Reference

### Common Commands

```bash
# Development workflow
git checkout Jeffery
git pull origin Jeffery
./scripts/local/test-local.sh
git add backend/
git commit -m "feat: description"
git push origin Jeffery

# Testing
./scripts/local/test-local.sh           # Run tests
./scripts/local/build-local.sh          # Build Docker
docker run --rm -p 8000:8000 aws-lab-flask-demo:local  # Run container

# Check Jenkins
open http://localhost:8080/blue         # View builds (macOS)
xdg-open http://localhost:8080/blue     # View builds (Linux)

# Dependencies
pip install package-name
pip freeze > requirements.txt
```

### Important Files

| File | Purpose | Modify? |
|------|---------|---------|
| `backend/src/app.py` | Your application code | ✅ Yes |
| `backend/tests/` | Your tests | ✅ Yes |
| `backend/requirements.txt` | Dependencies | ✅ Yes |
| `backend/Dockerfile` | Container config | ⚠️  Ask first |
| `ci/Jenkinsfile` | CI/CD pipeline | ❌ No |
| `demo-backend/` | Demo for validation | ❌ No |

### Jenkins Build Status

- 🟢 **Green** (Success) - All tests passed, ready to merge
- 🔴 **Red** (Failed) - Tests failed, fix before continuing
- 🟡 **Yellow** (Building) - In progress, wait for completion
- ⚪ **Gray** (Not built) - No build yet

## Additional Resources

- **[README.md](README.md)** - Project overview and setup
- **[BRANCH_STRATEGY.md](BRANCH_STRATEGY.md)** - Detailed CI/CD workflow
- **[docs/archived/DEVELOPMENT_DIARY.md](docs/archived/DEVELOPMENT_DIARY.md)** - Implementation history
- **[backend/README.md](backend/README.md)** - Backend-specific guide
- **[scripts/README.md](scripts/README.md)** - Script documentation

## Welcome to the Team!

You now have everything you need to start contributing. Remember:

1. **Always work on Jeffery branch** for development
2. **Run tests before pushing** every time
3. **Ask questions** if anything is unclear
4. **Review documentation** when needed

Happy coding! 🚀

---

**Last Updated:** 2025-11-22
**Maintained by:** Project Team
**Questions?** Contact team lead or post in #project-ci-cd
