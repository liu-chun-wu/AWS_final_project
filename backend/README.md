# Production Backend - AI Generation Service

This backend provides AI-powered image and audio generation using HuggingFace and Suno APIs, with AWS S3 storage and DynamoDB history tracking.

## Overview

The production backend has been integrated with NeoYeh's AI generation capabilities, providing endpoints for:
- **Image Generation**: AI-generated images via HuggingFace Stable Diffusion XL
- **Audio Generation**: AI-generated music via Suno API
- **User History**: DynamoDB-based generation history

All generated content is stored in S3 with presigned URLs for secure downloads.

## API Endpoints

### GET /health
Health check endpoint for monitoring.

**Response:**
```json
{
  "status": "ok",
  "service": "production-backend"
}
```

### POST /generate-image
Generate AI images using text prompts.

**Request:**
```json
{
  "prompt": "a beautiful sunset over mountains",
  "user_id": "user123"
}
```

**Response:**
```json
{
  "success": true,
  "download_url": "https://...",
  "reply": "Flask 收到圖片prompt: ..."
}
```

### POST /generate-audio
Generate AI music using text descriptions (async).

**Request:**
```json
{
  "prompt": "relaxing piano music",
  "user_id": "user123"
}
```

**Response:**
```json
{
  "success": true,
  "task_id": "...",
  "download_url": "https://...",
  "message": "音樂生成中"
}
```

### POST /audio-callback
Webhook endpoint for Suno API callback (internal use).

### GET /history?user_id=xxx
Retrieve generation history for a user.

**Response:**
```json
{
  "success": true,
  "records": [
    {
      "prompt": "...",
      "file_url": "https://...",
      "type": "image"
    }
  ]
}
```

## Environment Variables

Create a `.env` file in the `backend/` directory with:

```bash
# HuggingFace API Configuration
HUGGINGFACE_TOKEN=hf_your_token_here

# Suno AI API Configuration
SUNO_TOKEN=your_suno_token_here

# AWS S3 Configuration
S3_BUCKET_NAME=your-bucket-name-here

# AWS DynamoDB Configuration
AWS_DEFAULT_REGION=us-east-1
DYNAMODB_TABLE=UserRecords
```

**Security Note:** Never commit `.env` files to Git. Use `.env.example` for documentation.

## AWS Resources Required

Before deployment, ensure these AWS resources exist:

1. **S3 Bucket**: For storing generated images and audio files
   - Must have proper CORS configuration
   - Public read access for generated content

2. **DynamoDB Table**: `UserRecords`
   - Partition key: `user_id` (String)
   - Sort key: `record_id` (String)

3. **IAM Role**: Lambda execution role with permissions for:
   - S3: `PutObject`, `GetObject`, `GeneratePresignedUrl`
   - DynamoDB: `PutItem`, `Query`, `GetItem`

## Directory Structure

```
backend/
├── src/
│   ├── app.py              # Main Flask application with AI endpoints
│   └── db.py               # DynamoDB helper functions
├── tests/
│   ├── unit/               # Unit tests (12 tests)
│   │   ├── test_health.py
│   │   ├── test_generate_image.py
│   │   └── test_generate_audio.py
│   └── integration/        # Integration tests (5 tests)
│       └── test_api.py
├── requirements.txt        # Python dependencies (includes boto3, requests, Pillow)
├── Dockerfile             # Lambda-compatible container (300s timeout)
└── README.md             # This file
```

## Getting Started

1. **Install dependencies:**
   ```bash
   cd backend
   python3.11 -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your API tokens and AWS configuration
   ```

3. **Run tests:**
   ```bash
   pytest tests/unit -v
   pytest tests/integration -v
   ```

4. **Run locally:**
   ```bash
   python src/app.py
   # Server starts on http://localhost:8000
   ```

## Testing Locally

### Run all tests:
```bash
cd backend
pytest tests/ -v
```

### Run specific test suites:
```bash
pytest tests/unit -v           # Unit tests only
pytest tests/integration -v    # Integration tests only
```

### Build Docker image locally:
```bash
./scripts/local/build-local.sh --prod
```

### Run containerized app:
```bash
docker run --rm -p 8000:8000 \
  -e HUGGINGFACE_TOKEN=xxx \
  -e SUNO_TOKEN=xxx \
  -e S3_BUCKET_NAME=xxx \
  -e AWS_DEFAULT_REGION=us-east-1 \
  -e DYNAMODB_TABLE=UserRecords \
  aws-lab-flask-demo:local
```

## CI/CD Workflow

### Development (Jeffery Branch)
Push to Jeffery branch runs **CI only** (no AWS deployment):
- Checkout code
- Setup Python environment
- Install dependencies (including boto3, requests, Pillow)
- Run tests (17 tests must pass)
- Build Docker image with 300s timeout

```bash
git checkout Jeffery
# ... make changes ...
git add .
git commit -m "feat: your feature"
git push origin Jeffery
```

Jenkins will test and build but NOT deploy to AWS.

### Production Deployment
Manual deployment via Jenkins `flask-cd` job:
- Specify `BACKEND_DIR=backend`
- Specify `IMAGE_TAG` (or leave blank for latest)
- Deploy to Lambda with SAM

```bash
# After CI passes on Jeffery:
# Jenkins UI → flask-cd → Build with Parameters
# - BACKEND_DIR: backend
# - IMAGE_TAG: (leave blank or specify tag)
```

## Important Notes

1. **Python Version:** Must use Python 3.11 (AWS Lambda compatibility)

2. **Tests Must Pass:** All 17 tests (12 unit + 5 integration) must pass for CI to succeed

3. **Timeout:** Dockerfile uses 300s timeout (5 minutes) for AI API calls

4. **Port:** Application listens on port 8000

5. **Stateless Design:** No local state; uses S3 for files and DynamoDB for history

6. **API Tokens:** Require valid HuggingFace and Suno tokens for full functionality

7. **AWS Resources:** S3 bucket and DynamoDB table must be provisioned before deployment

## Dependencies

Key Python packages:
- **Flask 3.0.0**: Web framework
- **gunicorn 21.2.0**: Production WSGI server
- **boto3 1.34.0**: AWS SDK for S3 and DynamoDB
- **requests 2.31.0**: HTTP client for external APIs
- **Pillow 10.2.0**: Image processing
- **python-dotenv 1.0.0**: Environment variable management
- **pytest 7.4.3**: Testing framework

Optional:
- **discord.py 2.3.2**: Discord bot integration (not used in Lambda)
- **aiohttp 3.9.1**: Async HTTP client for Discord

## Deployment Configuration

This backend uses the **production** SAM configuration:
- Config file: `aws/samconfig-prod.toml`
- Stack name: `flask-prod-backend`
- Lambda timeout: 30 seconds (increase if needed for API calls)
- Memory: 512 MB

## Troubleshooting

### Tests fail with "No module named 'db'"
Make sure imports use `from src.db import ...` not `from db import ...`

### API returns 500 on generate endpoints
Check that environment variables are set correctly:
- `HUGGINGFACE_TOKEN`
- `SUNO_TOKEN`
- `S3_BUCKET_NAME`
- `DYNAMODB_TABLE`

### S3 upload fails
Verify Lambda role has S3 permissions:
- `s3:PutObject`
- `s3:GetObject`

### DynamoDB errors
Verify:
- Table exists with correct name
- Table has partition key `user_id` (String)
- Lambda role has DynamoDB permissions

## Need Help?

- **Branch Strategy:** See `BRANCH_STRATEGY.md`
- **Collaboration Guide:** See `COLLABORATION.md`
- **Scripts Documentation:** See `scripts/README.md`
- **Integration Spec:** See the c_prompts.txt for detailed integration documentation

## Demo Backend

For CI/CD validation reference, see `demo-backend/` which contains:
- Simple Flask app with /health and /echo endpoints
- 18 passing tests
- Working CI/CD pipeline configuration
- Serves as the immutable CI/CD validation baseline
