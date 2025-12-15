# Demo Backend - CI/CD Validation

Simple Flask application used to validate the CI/CD pipeline.

## Purpose

This backend serves as the **immutable baseline** for testing the CI/CD pipeline:
- Validate Jenkins CI/CD jobs
- Test Docker build process
- Verify SAM deployment
- Confirm API Gateway routing

**Do not modify** - use `backend/` for production development.

## Directory Structure

```
demo-backend/
├── src/
│   └── app.py          # Flask application
├── tests/
│   ├── unit/           # 6 unit tests
│   └── integration/    # 12 integration tests
├── Dockerfile          # Lambda-compatible container
└── requirements.txt    # Python dependencies
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Returns `{"status": "ok", "service": "demo-backend"}` |
| `/echo` | POST | Echoes back request body |

## Quick Start

```bash
# Setup
cd demo-backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run tests
pytest tests/ -v

# Run locally
python src/app.py
```

## Testing the Pipeline

```bash
# Test demo backend
./scripts/local/test-local.sh --demo

# Build demo image
./scripts/local/build-local.sh --demo

# Full CI/CD (requires AWS)
./scripts/jenkins/20-ci-build-and-push.sh --demo
./scripts/jenkins/31-cd-deploy-sam.sh --demo
./scripts/jenkins/32-cd-verify-deployment.sh --demo
```

## Test Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Echo test
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "hello"}'
```

**Test counts:** 18 total (6 unit + 12 integration)

## Full Documentation

See [docs/CI_CD.md](../docs/CI_CD.md) for:
- Pipeline architecture
- Jenkins setup
- Deployment guide

## See Also

- [CI/CD Pipeline](../docs/CI_CD.md)
- [Testing Guide](../docs/TESTING.md)
- [Scripts Reference](../docs/SCRIPTS.md)
