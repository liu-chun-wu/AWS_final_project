# Testing Guide

Comprehensive guide for testing the application locally, in Docker, and through CI/CD.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Local Testing (pytest)](#local-testing-pytest)
- [Docker Testing](#docker-testing)
- [Discord Bot Testing](#discord-bot-testing)
- [CI/CD Pipeline Testing](#cicd-pipeline-testing)
- [Validation Checklist](#validation-checklist)

---

## Overview

### Test Summary

| Backend | Unit Tests | Integration Tests | Total |
|---------|------------|-------------------|-------|
| backend (production) | 12 | 5 | 17 |
| demo-backend (CI/CD validation) | 6 | 12 | 18 |

### Testing Philosophy

- **Unit Tests**: Test individual functions/endpoints in isolation
- **Integration Tests**: Test full request/response cycle
- **No External Dependencies**: Tests don't require AWS or API tokens
- **Fail Fast**: CI pipeline stops on first test failure

---

## Test Structure

### Production Backend (`backend/tests/`)

```
backend/tests/
├── __init__.py
├── unit/
│   ├── __init__.py
│   ├── test_health.py          # 5 tests
│   ├── test_generate_image.py  # 4 tests
│   └── test_generate_audio.py  # 3 tests
└── integration/
    ├── __init__.py
    └── test_api.py             # 5 tests
```

### Demo Backend (`demo-backend/tests/`)

```
demo-backend/tests/
├── __init__.py
├── unit/
│   ├── __init__.py
│   └── test_health.py          # 6 tests
└── integration/
    ├── __init__.py
    └── test_echo.py            # 12 tests
```

---

## Local Testing (pytest)

### Quick Start

```bash
# Using script (recommended)
./scripts/local/test-local.sh --prod    # Production backend
./scripts/local/test-local.sh --demo    # Demo backend

# Or manually
cd backend
source .venv/bin/activate
pytest tests/ -v
```

### Run Specific Tests

```bash
cd backend

# All tests
pytest tests/ -v

# Unit tests only
pytest tests/unit/ -v

# Integration tests only
pytest tests/integration/ -v

# Single test file
pytest tests/unit/test_health.py -v

# Single test function
pytest tests/unit/test_health.py::test_health_endpoint_returns_200 -v

# With coverage
pytest tests/ -v --cov=src --cov-report=html
```

### Test Output Example

```
======================== test session starts ========================
collected 17 items

tests/unit/test_health.py::test_health_returns_200 PASSED
tests/unit/test_health.py::test_health_returns_json PASSED
tests/unit/test_health.py::test_health_json_structure PASSED
tests/unit/test_generate_image.py::test_endpoint_exists PASSED
...
======================== 17 passed in 0.42s =========================
```

### Test Categories

**Health Endpoint Tests:**
- Returns 200 status code
- Returns JSON content type
- Has correct structure (`status`, `service`)
- Only accepts GET method

**Generate Image Tests:**
- Endpoint exists and is routable
- Only accepts POST method
- Returns 400 for missing prompt
- Returns 400 for empty prompt

**Generate Audio Tests:**
- Endpoint exists and is routable
- Only accepts POST method
- Returns 400 for missing prompt

**Integration Tests:**
- All endpoints are routable (not 404)
- Invalid methods return 405
- All responses are valid JSON
- Error handling returns proper messages

---

## Docker Testing

### Build and Run

```bash
# Build image
cd backend
docker build -t aws-lab-flask-demo:local .

# Run container
docker run -d --name flask-test -p 8000:8000 --env-file .env aws-lab-flask-demo:local

# Wait for startup
sleep 3
```

### Test Endpoints

```bash
# Health check
curl http://localhost:8000/health
# Expected: {"service":"production-backend","status":"ok"}

# Generate image (requires valid .env)
curl -X POST http://localhost:8000/generate-image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a cute cat","user_id":"test"}'

# Generate audio (requires Suno credits)
curl -X POST http://localhost:8000/generate-audio \
  -H "Content-Type: application/json" \
  -d '{"prompt":"relaxing piano","user_id":"test"}'
```

### View Logs

```bash
# Follow logs
docker logs flask-test -f

# Last 50 lines
docker logs flask-test --tail 50

# Search for errors
docker logs flask-test 2>&1 | grep -i error
```

### Cleanup

```bash
docker stop flask-test
docker rm flask-test
```

---

## Discord Bot Testing

The Discord bot (`test-discord-bot.py`) provides interactive testing through Discord.

### Prerequisites

- Docker container running
- `DISCORD_TOKEN` in `backend/.env`
- Python with `discord.py` installed

### Start Testing

```bash
# Method 1: Automated script
cd backend
bash start-discord-test.sh

# Method 2: Manual
# Terminal 1: Start backend
docker run -d --name flask-test -p 8000:8000 --env-file backend/.env aws-lab-flask-demo:local

# Terminal 2: Start bot
python test-discord-bot.py
```

### Bot Commands

| Command | Description | Expected Result |
|---------|-------------|-----------------|
| `!health` | Check backend health | Backend status JSON |
| `!image <prompt>` | Generate AI image | Image embed in Discord |
| `!audio <prompt>` | Generate AI music | Task ID and URL |
| `!history` | View generation history | List of past generations |
| `!ping` | Check bot latency | Latency in ms |
| `!commands` | Show help | List of commands |

### Test Workflow

1. `!health` - Verify backend connectivity
2. `!image a cute cat` - Test image generation
3. `!ping` - Check bot responsiveness
4. `!audio calm piano` - Test audio (shows credit error if no credits)
5. `!history` - Test history (shows DynamoDB error if no table)

### Expected Behaviors

| Feature | Working | Error (Expected) |
|---------|---------|------------------|
| Health check | Returns status | - |
| Image generation | Shows image | HuggingFace API error |
| Audio generation | Task ID returned | "Insufficient credits" |
| History | Shows records | DynamoDB not found |

---

## CI/CD Pipeline Testing

### Local CI Test

```bash
# Run full CI locally (without Jenkins)
./scripts/jenkins/20-ci-build-and-push.sh --prod

# This runs:
# 1. pytest tests
# 2. Docker build
# 3. ECR push (if AWS configured)
```

### Jenkins CI Test

1. Push to Jeffery branch
2. Watch Jenkins CI job
3. Verify all stages pass:
   - Checkout
   - Branch Validation
   - Setup
   - Tests
   - Build
   - Push

### CD Verification

```bash
# After deployment, verify endpoints
./scripts/jenkins/32-cd-verify-deployment.sh --prod

# Manual verification
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health
```

---

## Validation Checklist

### Local Environment

| Check | Command | Expected |
|-------|---------|----------|
| Python version | `python --version` | 3.11.x |
| Docker running | `docker ps` | No error |
| Tests pass | `./scripts/local/test-local.sh --prod` | 17 passed |
| Docker builds | `./scripts/local/build-local.sh --prod` | Success |
| Container runs | `curl localhost:8000/health` | `{"status":"ok"}` |

### CI/CD Pipeline

| Check | Action | Expected |
|-------|--------|----------|
| Manual CI | `./scripts/jenkins/20-ci-build-and-push.sh` | Image pushed to ECR |
| Manual CD | `./scripts/jenkins/31-cd-deploy-sam.sh` | Stack deployed |
| Verify deploy | `./scripts/jenkins/32-cd-verify-deployment.sh` | Endpoints respond |
| Jenkins CI | Push to Jeffery | Job succeeds |
| Jenkins CD | Run flask-cd job | Deployment succeeds |

### AWS Resources

| Check | Command | Expected |
|-------|---------|----------|
| AWS credentials | `aws sts get-caller-identity` | Account info |
| ECR images | `aws ecr describe-images --repo aws-lab-flask-demo` | Image list |
| Lambda function | `aws lambda get-function --function-name FlaskDemoFunction` | Function info |
| API Gateway | Check URL in SAM outputs | 200 response |

### End-to-End

| Step | Action | Expected |
|------|--------|----------|
| 1 | Make code change | - |
| 2 | Run local tests | All pass |
| 3 | Push to Jeffery | CI job starts |
| 4 | CI completes | Image in ECR |
| 5 | Run CD job | Stack updates |
| 6 | Test API | Endpoints work |

---

## Troubleshooting Tests

### Tests Won't Run

**Error:** `ModuleNotFoundError`

```bash
# Ensure virtual environment is active
source backend/.venv/bin/activate

# Reinstall dependencies
pip install -r backend/requirements.txt
```

### Tests Fail on Import

**Error:** `ImportError: cannot import name 'create_app'`

```bash
# Run from correct directory
cd backend
pytest tests/ -v

# Or use full path
pytest backend/tests/ -v
```

### Docker Tests Fail

**Error:** Connection refused

```bash
# Check container is running
docker ps

# Check logs for errors
docker logs flask-test

# Ensure port mapping
docker run -p 8000:8000 ...
```

### Discord Bot Issues

**Error:** `ModuleNotFoundError: No module named 'discord'`

```bash
pip install discord.py aiohttp
```

**Error:** Bot doesn't respond

- Check bot is connected (look for "Shard ID None has connected")
- Verify backend is running (`curl localhost:8000/health`)
- Check bot token is correct

---

## See Also

- [Application Documentation](APPLICATION.md)
- [CI/CD Pipeline](CI_CD.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Scripts Reference](SCRIPTS.md)
