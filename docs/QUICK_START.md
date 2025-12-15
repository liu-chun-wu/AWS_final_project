# Quick Start Guide

Get the project running in 5 minutes.

## Prerequisites

- Python 3.11
- Docker Desktop (running)
- AWS CLI configured
- Git

## 1. Clone and Setup

```bash
# Clone repository
git clone <repository-url>
cd AWS_final_project

# Setup Python environment
cd backend
python3.11 -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## 2. Run Tests

```bash
# From project root
./scripts/local/test-local.sh --prod

# Or manually
cd backend
pytest tests/ -v
```

## 3. Build Docker Image

```bash
# From project root
./scripts/local/build-local.sh --prod

# Or manually
cd backend
docker build -t aws-lab-flask-demo:local .
```

## 4. Run Locally

```bash
# Run container
docker run --rm -p 8000:8000 --env-file .env aws-lab-flask-demo:local

# Test health endpoint
curl http://localhost:8000/health
```

## 5. Deploy to AWS

```bash
# Setup ECR (one-time)
./scripts/jenkins/11-setup-ecr.sh

# Build and push to ECR
./scripts/jenkins/20-ci-build-and-push.sh --prod

# Deploy via SAM
./scripts/jenkins/31-cd-deploy-sam.sh --prod

# Verify deployment
./scripts/jenkins/32-cd-verify-deployment.sh --prod
```

## 6. Verify Deployment

```bash
# Get API URL from SAM output, then:
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health
```

---

## What's Next?

| Goal | Documentation |
|------|---------------|
| Understand the architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Learn about the application | [APPLICATION.md](APPLICATION.md) |
| Set up CI/CD pipeline | [CI_CD.md](CI_CD.md) |
| Run tests | [TESTING.md](TESTING.md) |
| Troubleshoot issues | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

## Environment Variables

For full functionality, create `backend/.env`:

```bash
# Required for AWS
AWS_ACCESS_KEY_ID=<your-key>
AWS_SECRET_ACCESS_KEY=<your-secret>
AWS_SESSION_TOKEN=<your-token>
AWS_DEFAULT_REGION=us-east-1

# Required for AI features
HUGGINGFACE_TOKEN=<your-token>
S3_BUCKET_NAME=<your-bucket>

# Optional
SUNO_TOKEN=<your-token>
DYNAMODB_TABLE=UserRecords
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Python not found | Ensure Python 3.11 is installed |
| Docker not running | Start Docker Desktop |
| AWS credentials expired | Refresh from AWS Learner Lab |
| Tests fail | Check `backend/.env` exists |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.
