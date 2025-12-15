# Production Backend - AI Generation Service

Flask-based REST API providing AI-powered image and music generation.

## Overview

This backend provides:
- **Image Generation** - HuggingFace Stable Diffusion XL
- **Music Generation** - Suno API (async)
- **File Storage** - AWS S3 with presigned URLs
- **History Tracking** - AWS DynamoDB (optional)

## Directory Structure

```
backend/
├── src/
│   ├── app.py          # Flask application
│   └── db.py           # DynamoDB helpers
├── tests/
│   ├── unit/           # 12 unit tests
│   └── integration/    # 5 integration tests
├── Dockerfile          # Lambda-compatible container
├── requirements.txt    # Python dependencies
└── .env               # Environment variables (not in git)
```

## Quick Start

```bash
# Setup
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run tests
pytest tests/ -v

# Run locally
python src/app.py
# OR
gunicorn --bind 0.0.0.0:8000 src.app:create_app()
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/generate-image` | POST | Generate AI image |
| `/generate-audio` | POST | Generate AI music (async) |
| `/audio-callback` | POST | Suno webhook |
| `/history` | GET | User generation history |

## Environment Variables

Create `.env` file:

```bash
# AWS
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_SESSION_TOKEN=...
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET_NAME=...

# AI APIs
HUGGINGFACE_TOKEN=...
SUNO_TOKEN=...

# Optional
DYNAMODB_TABLE=UserRecords
```

## Docker

```bash
# Build
docker build -t aws-lab-flask-demo:local .

# Run
docker run -d -p 8000:8000 --env-file .env aws-lab-flask-demo:local

# Test
curl http://localhost:8000/health
```

## Full Documentation

See [docs/APPLICATION.md](../docs/APPLICATION.md) for:
- Detailed API reference
- Architecture diagrams
- Design decisions
- Troubleshooting

## Testing

```bash
# All tests
pytest tests/ -v

# Unit only
pytest tests/unit/ -v

# Integration only
pytest tests/integration/ -v
```

**Test counts:** 17 total (12 unit + 5 integration)

## See Also

- [Application Documentation](../docs/APPLICATION.md)
- [Testing Guide](../docs/TESTING.md)
- [CI/CD Pipeline](../docs/CI_CD.md)
