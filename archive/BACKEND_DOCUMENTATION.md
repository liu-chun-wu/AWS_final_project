# Backend Documentation

**Project:** NeoYeh AI Generation Backend Integration
**Created:** 2025-12-09
**Last Updated:** 2025-12-10
**Status:** Production Ready ✅

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Core Files](#core-files)
5. [Scripts](#scripts)
6. [API Endpoints](#api-endpoints)
7. [Environment Configuration](#environment-configuration)
8. [Testing](#testing)
9. [Docker Configuration](#docker-configuration)
10. [Discord Bot Integration](#discord-bot-integration)
11. [Development Workflow](#development-workflow)
12. [Troubleshooting](#troubleshooting)

---

## Overview

This backend integrates NeoYeh's AI generation capabilities into the Jeffery_2 CI/CD template project. It provides RESTful API endpoints for:

- **AI Image Generation** - Using HuggingFace Stable Diffusion XL
- **AI Music Generation** - Using Suno API (async with webhooks)
- **Generation History Tracking** - Using AWS DynamoDB
- **File Storage** - Using AWS S3 with presigned URLs

### Key Features

- ✅ Stateless REST API (Flask 3.0.0)
- ✅ Production WSGI server (Gunicorn)
- ✅ Docker containerization with Lambda Web Adapter
- ✅ AWS integration (S3, DynamoDB)
- ✅ External AI API integration (HuggingFace, Suno)
- ✅ Discord bot client for testing
- ✅ Automated startup scripts
- ✅ Comprehensive test coverage (17 tests)

---

## Architecture

### System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
│  ┌────────────────┐              ┌─────────────────────┐        │
│  │ Discord Bot    │              │ Direct HTTP Client  │        │
│  │ (test-discord- │              │ (curl, Postman)     │        │
│  │  bot.py)       │              │                     │        │
│  └────────┬───────┘              └──────────┬──────────┘        │
└───────────┼───────────────────────────────────┼─────────────────┘
            │                                   │
            └───────────────┬───────────────────┘
                            │ HTTP REST API
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Backend API Layer                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           Flask Application (src/app.py)                 │  │
│  │  ┌────────────┐  ┌──────────────┐  ┌─────────────────┐ │  │
│  │  │  /health   │  │/generate-    │  │  /generate-     │ │  │
│  │  │            │  │  image       │  │    audio        │ │  │
│  │  └────────────┘  └──────────────┘  └─────────────────┘ │  │
│  │  ┌────────────┐  ┌──────────────┐                       │  │
│  │  │  /history  │  │/audio-       │                       │  │
│  │  │            │  │  callback    │                       │  │
│  │  └────────────┘  └──────────────┘                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Database Helper (src/db.py)                     │  │
│  │  - insert_record()                                       │  │
│  │  - get_history()                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
            │                   │                   │
            │                   │                   │
            ▼                   ▼                   ▼
┌──────────────────┐  ┌─────────────────┐  ┌──────────────────┐
│ HuggingFace API  │  │   Suno API      │  │   AWS Services   │
│ (Stable Diff XL) │  │ (Music Gen)     │  │  - S3 Storage    │
│                  │  │                 │  │  - DynamoDB      │
└──────────────────┘  └─────────────────┘  └──────────────────┘
```

### Data Flow: Image Generation

1. Client sends POST to `/generate-image` with `{prompt, user_id}`
2. Backend calls HuggingFace API to generate image
3. Backend uploads image to S3 bucket
4. Backend attempts to save record to DynamoDB (non-fatal if fails)
5. Backend generates presigned S3 URL (1 hour expiry)
6. Backend returns `{success: true, download_url: "..."}`
7. Client displays/downloads image

### Data Flow: Audio Generation (Async)

1. Client sends POST to `/generate-audio` with `{prompt, user_id}`
2. Backend pre-generates S3 key and callback URL
3. Backend calls Suno API with callback URL
4. Backend returns immediately with `{success: true, task_id: "..."}`
5. **Later:** Suno completes generation and calls `/audio-callback`
6. Backend downloads audio from Suno, uploads to S3
7. Backend saves record to DynamoDB
8. Audio is available at presigned URL

---

## Directory Structure

```
backend/
├── src/                          # Application source code
│   ├── app.py                   # Main Flask application (449 lines)
│   └── db.py                    # DynamoDB helper functions (69 lines)
│
├── tests/                        # Test suite
│   ├── unit/                    # Unit tests (12 tests)
│   │   ├── test_health.py       # Health endpoint tests (5 tests)
│   │   ├── test_generate_image.py  # Image endpoint tests (4 tests)
│   │   └── test_generate_audio.py  # Audio endpoint tests (3 tests)
│   └── integration/             # Integration tests (5 tests)
│       └── test_api.py          # Full API surface tests
│
├── Dockerfile                    # Container configuration
├── requirements.txt             # Python dependencies
├── README.md                    # API documentation
├── .dockerignore               # Docker build exclusions
├── .env                        # Environment variables (DO NOT COMMIT)
│
├── start-discord-test.sh       # Startup script (Bash/WSL)
├── start-discord-test.bat      # Startup script (Windows)
└── BACKEND_DOCUMENTATION.md    # This file

Related Files (Project Root):
├── test-discord-bot.py         # Discord bot client (275 lines)
├── DISCORD_BOT_TESTING_GUIDE.md  # Discord testing guide
└── FILE_OVERVIEW.md            # Project architecture docs
```

---

## Core Files

### 1. `src/app.py` (449 lines)

**Purpose:** Main Flask application with AI generation endpoints

**Key Components:**

#### Application Factory Pattern
```python
def create_app(config=None):
    """Creates and configures Flask application"""
    app = Flask(__name__)
    load_dotenv()

    # Initialize AWS clients
    app.s3 = boto3.client("s3")

    # Load API tokens
    app.huggingface_token = os.getenv("HUGGINGFACE_TOKEN")
    app.suno_token = os.getenv("SUNO_TOKEN")
    app.s3_bucket_name = os.getenv("S3_BUCKET_NAME")

    register_routes(app)
    return app
```

#### Routes

1. **GET /health** (Lines 82-92)
   - Health check endpoint
   - Returns: `{"status": "ok", "service": "production-backend"}`
   - No authentication required

2. **POST /generate-image** (Lines 94-204)
   - Generate AI images using HuggingFace Stable Diffusion XL
   - Request: `{"prompt": str, "user_id": str}`
   - Process:
     - Calls HuggingFace API (timeout: 60s)
     - Uploads to S3
     - Saves to DynamoDB (non-fatal)
     - Generates presigned URL (1hr expiry)
   - Response: `{"success": bool, "download_url": str}`

3. **POST /generate-audio** (Lines 205-320)
   - Generate AI music using Suno API (async)
   - Request: `{"prompt": str, "user_id": str}`
   - Process:
     - Pre-generates S3 key and callback URL
     - Calls Suno API with webhook
     - Returns immediately (doesn't wait for completion)
   - Response: `{"success": bool, "task_id": str, "download_url": str}`

4. **POST /audio-callback** (Lines 322-406)
   - Webhook endpoint for Suno API completion
   - Called by Suno when audio generation completes
   - Process:
     - Downloads audio from Suno URL
     - Uploads to S3
     - Saves to DynamoDB
   - Response: `{"success": bool}`

5. **GET /history** (Lines 408-447)
   - Retrieve user's generation history
   - Query params: `?user_id=<user_id>`
   - Process:
     - Queries DynamoDB by user_id
     - Returns list of records
   - Response: `{"success": bool, "records": [...]}`

**Key Design Decisions:**

- **Stateless:** No session management, pure request/response
- **Non-fatal DynamoDB:** Image/audio generation succeeds even if history tracking fails
- **Presigned URLs:** S3 URLs expire after 1 hour for security
- **Async Audio:** Suno generates audio in background, uses webhook callback
- **Error Handling:** All endpoints return consistent JSON error format

### 2. `src/db.py` (69 lines)

**Purpose:** DynamoDB helper functions for generation history tracking

**Functions:**

#### `insert_record()`
```python
def insert_record(user_id: str, prompt: str, file_url: str,
                  record_type: str = "image", status: str = "success",
                  extra_meta: dict = None):
    """
    Insert generation record to DynamoDB

    Schema:
        - user_id (partition key): User identifier
        - record_id (sort key): UUID for this record
        - prompt: Generation prompt text
        - file_url: S3 URL to generated file
        - created_at: ISO 8601 timestamp
        - type: "image" or "audio"
        - status: "success" or "failed"
        - extra_meta: Optional additional data
    """
```

#### `get_history()`
```python
def get_history(user_id: str):
    """
    Query user's generation history

    Returns:
        List of records with prompt, file_url, and type
    """
```

**DynamoDB Table Schema:**
```
Table Name: UserRecords
Partition Key: user_id (String)
Sort Key: record_id (String)

Attributes:
- user_id: String (PK)
- record_id: String (SK) - UUID
- prompt: String
- file_url: String (S3 URL)
- created_at: String (ISO 8601)
- type: String ("image" or "audio")
- status: String ("success" or "failed")
- extra_meta: Map (optional)
```

---

## Scripts

### 1. `start-discord-test.sh` (222 lines)

**Purpose:** Automated startup script for Discord bot testing (Bash/WSL)

**What It Does:**

1. **Prerequisites Check**
   - Verifies Docker is installed and running
   - Verifies Python is available
   - Checks for `.env` file
   - Checks for `test-discord-bot.py`

2. **Backend Startup**
   - Removes existing container if present
   - Starts new Docker container with .env loaded
   - Maps port 8000:8000
   - Runs in detached mode

3. **Health Check Wait Loop**
   - Polls `http://localhost:8000/health`
   - Max 10 retries with 2-second intervals
   - Shows health response when ready

4. **Discord Bot Startup**
   - Changes to project root directory
   - Detects which Python has discord.py installed
   - Starts Discord bot in foreground
   - Shows bot output in terminal

5. **Cleanup on Exit**
   - Ctrl+C triggers cleanup function
   - Stops Discord bot (automatic)
   - Stops backend container
   - Clean exit

**Key Features:**

- ✅ Colored output (green/blue/yellow/red)
- ✅ Automatic cleanup with trap
- ✅ Smart Python detection (checks for discord.py)
- ✅ Error handling at each step
- ✅ Health check with retries

**Usage:**
```bash
cd backend
bash start-discord-test.sh

# To stop: Press Ctrl+C
```

**Configuration (Lines 33-38):**
```bash
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${BACKEND_DIR}/.." && pwd)"
CONTAINER_NAME="flask-test-container"
BACKEND_PORT="8000"
IMAGE_NAME="aws-lab-flask-demo:local"
ENV_FILE="${BACKEND_DIR}/.env"
```

### 2. `start-discord-test.bat` (195 lines)

**Purpose:** Automated startup script for Discord bot testing (Windows)

**Functionality:** Same as bash script, adapted for Windows CMD/PowerShell

**Key Differences from Bash Script:**
- Uses batch syntax (`@echo off`, `set`, `if errorlevel`)
- Uses `timeout` instead of `sleep`
- Uses `cd /d` for directory changes
- Uses `findstr` instead of `grep`
- No colored output (Windows CMD limitation)

**Usage:**
```cmd
cd backend
start-discord-test.bat

REM To stop: Press Ctrl+C
```

**Why Two Scripts?**

- **Bash script:** For users with Git Bash, WSL, or Linux/Mac
- **Batch script:** For users who prefer native Windows CMD
- Both provide identical functionality
- Both ensure consistent testing experience

---

## API Endpoints

### Complete API Reference

#### 1. Health Check

**Endpoint:** `GET /health`
**Purpose:** Verify backend is running
**Auth:** None

**Response:**
```json
{
  "status": "ok",
  "service": "production-backend"
}
```

**Status Codes:**
- `200` - Backend healthy

---

#### 2. Generate Image

**Endpoint:** `POST /generate-image`
**Purpose:** Generate AI image using HuggingFace Stable Diffusion XL
**Timeout:** 60 seconds

**Request:**
```json
{
  "prompt": "a cute cat playing with yarn",
  "user_id": "discord_123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "download_url": "https://tmp-230909.s3.amazonaws.com/Images/20251210123456_abc123.png?AWSAccessKeyId=...",
  "reply": "Flask 收到圖片prompt: a cute cat playing with yarn"
}
```

**Error Responses:**
- `400` - Missing or invalid prompt
- `500` - HuggingFace API error, S3 upload error, or presigned URL generation error

**Process Flow:**
1. Validate prompt (must be non-empty string)
2. Call HuggingFace API with prompt
3. Upload generated image to S3 (`Images/<timestamp>_<uuid>.png`)
4. Attempt DynamoDB insert (non-fatal)
5. Generate presigned S3 URL (1 hour expiry)
6. Return success with download URL

---

#### 3. Generate Audio

**Endpoint:** `POST /generate-audio`
**Purpose:** Generate AI music using Suno API (async)
**Timeout:** 60 seconds (for API call only)

**Request:**
```json
{
  "prompt": "calm piano music",
  "user_id": "discord_123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "task_id": "suno_task_abc123",
  "download_url": "https://tmp-230909.s3.amazonaws.com/Audios/20251210123456_abc123.mp3?AWSAccessKeyId=...",
  "message": "音樂生成中"
}
```

**Error Responses:**
- `400` - Missing or invalid prompt
- `500` - Suno API error (e.g., insufficient credits)

**Important Notes:**
- Returns immediately (doesn't wait for audio generation)
- Audio will be uploaded to S3 when Suno completes generation
- Use presigned URL to download when ready
- Generation typically takes 1-2 minutes

---

#### 4. Audio Callback (Webhook)

**Endpoint:** `POST /audio-callback`
**Purpose:** Receive Suno API completion notification
**Auth:** None (webhook endpoint)

**Query Parameters:**
- `user_id` - User identifier
- `prompt` - Original prompt
- `s3_key` - Pre-generated S3 key

**Request Body (from Suno):**
```json
{
  "status": "completed",
  "audio_url": "https://suno.ai/download/abc123.mp3",
  "task_id": "abc123"
}
```

**Response:**
```json
{
  "success": true
}
```

**Process Flow:**
1. Extract audio URL from Suno callback
2. Download audio file from Suno
3. Upload to S3 using pre-generated key
4. Save record to DynamoDB
5. Return success

---

#### 5. Get History

**Endpoint:** `GET /history?user_id=<user_id>`
**Purpose:** Retrieve user's generation history
**Auth:** None

**Request:**
```
GET /history?user_id=discord_123456
```

**Success Response (200):**
```json
{
  "success": true,
  "records": [
    {
      "prompt": "a cute cat",
      "file_url": "https://tmp-230909.s3.amazonaws.com/Images/...",
      "type": "image"
    },
    {
      "prompt": "calm piano music",
      "file_url": "https://tmp-230909.s3.amazonaws.com/Audios/...",
      "type": "audio"
    }
  ]
}
```

**Error Responses:**
- `400` - Missing user_id parameter
- `500` - DynamoDB query error

---

## Environment Configuration

### Required Environment Variables

**File:** `backend/.env` (⚠️ DO NOT COMMIT TO GIT)

```env
# ============================================================================
# AWS Credentials (from AWS Learner Lab)
# ============================================================================
AWS_ACCESS_KEY_ID=ASIAXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_SESSION_TOKEN=IQoJb3JpZ2luX2VjXXXXXXXXXXXXXXXX...
AWS_DEFAULT_REGION=us-east-1

# ============================================================================
# AWS Resources
# ============================================================================
S3_BUCKET_NAME=tmp-230909
DYNAMODB_TABLE=UserRecords

# ============================================================================
# AI API Tokens
# ============================================================================
# HuggingFace Stable Diffusion XL
HUGGINGFACE_TOKEN=hf_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Suno Music Generation API
SUNO_TOKEN=your_suno_token_here

# ============================================================================
# Discord Bot (for testing)
# ============================================================================
DISCORD_TOKEN=MTQ0MTc4NzI5NjI3Njk0Mjk0OA.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXX
DISCORD_BOT_TOKEN=MTQ0MTc4NzI5NjI3Njk0Mjk0OA.XXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXX

# ============================================================================
# API Configuration (optional)
# ============================================================================
API_GATEWAY_URL=http://localhost:8000
```

### Environment Variable Details

| Variable | Required | Purpose | Example |
|----------|----------|---------|---------|
| `AWS_ACCESS_KEY_ID` | ✅ Yes | AWS authentication | `ASIA...` |
| `AWS_SECRET_ACCESS_KEY` | ✅ Yes | AWS authentication | `xxxxx...` |
| `AWS_SESSION_TOKEN` | ✅ Yes | AWS temporary credentials | `IQoJb...` |
| `AWS_DEFAULT_REGION` | ✅ Yes | AWS region | `us-east-1` |
| `S3_BUCKET_NAME` | ✅ Yes | S3 bucket for files | `tmp-230909` |
| `DYNAMODB_TABLE` | ⚠️ Optional | DynamoDB table name | `UserRecords` |
| `HUGGINGFACE_TOKEN` | ✅ Yes | HuggingFace API auth | `hf_...` |
| `SUNO_TOKEN` | ⚠️ Optional | Suno API auth | `...` |
| `DISCORD_TOKEN` | ⚠️ Optional | Discord bot token | `MTQ...` |
| `API_GATEWAY_URL` | ⚠️ Optional | Backend URL for bot | `http://localhost:8000` |

### AWS Learner Lab Notes

- **Credentials expire after 3-4 hours**
- Must refresh from AWS Learner Lab dashboard
- Update `.env` file after refreshing
- Recreate Docker container to load new credentials

---

## Testing

### Test Suite Overview

**Total Tests:** 17 tests
**Coverage:** Unit tests (12) + Integration tests (5)
**Framework:** pytest 7.4.3
**All tests pass:** ✅ (as of 2025-12-10)

### Test Structure

#### Unit Tests (12 tests)

**`tests/unit/test_health.py` (5 tests)**
- Health endpoint returns 200
- Returns JSON content type
- Returns expected structure
- Returns correct values
- Only accepts GET method

**`tests/unit/test_generate_image.py` (4 tests)**
- Endpoint exists and routable
- Only accepts POST method
- Returns 400 when prompt missing
- Returns 400 when prompt is empty string

**`tests/unit/test_generate_audio.py` (3 tests)**
- Endpoint exists and routable
- Only accepts POST method
- Returns 400 when prompt missing

#### Integration Tests (5 tests)

**`tests/integration/test_api.py` (5 tests)**
- All endpoints exist and are routable
- Health check returns expected JSON structure
- Invalid HTTP methods return 405
- All responses are valid JSON
- Error handling returns proper error messages

### Running Tests

**Run all tests:**
```bash
cd backend
pytest tests/ -v
```

**Run specific test file:**
```bash
pytest tests/unit/test_health.py -v
```

**Run single test:**
```bash
pytest tests/unit/test_health.py::test_health_endpoint_returns_200 -v
```

**Using the test script (WSL/Linux):**
```bash
cd ..  # Go to project root
bash scripts/local/test-local.sh --prod
```

### Test Strategy

**Unit Tests:**
- Test individual endpoints in isolation
- Mock external dependencies (no real API calls)
- Validate request/response structure
- Test error conditions

**Integration Tests:**
- Test full API surface
- Verify endpoint routing
- Validate JSON response format
- Test error handling across endpoints

**What Tests DON'T Do:**
- Don't call real HuggingFace API (no credits used)
- Don't call real Suno API (no credits used)
- Don't require AWS credentials
- Don't upload to S3
- Don't write to DynamoDB

This allows tests to run in CI/CD without external dependencies or credentials.

---

## Docker Configuration

### Dockerfile

**Base Image:** `python:3.11-slim`
**Final Image Size:** ~315MB (compressed: ~79MB)
**Runtime:** Gunicorn WSGI server
**Lambda Compatibility:** Uses AWS Lambda Web Adapter

**Key Components:**

```dockerfile
# Lambda Web Adapter for container-based Lambda
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# Working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Run with Gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--timeout", "300", "src.app:create_app()"]
```

**Configuration Details:**

| Setting | Value | Reason |
|---------|-------|--------|
| Workers | 1 | Single worker for simplicity |
| Timeout | 300s | AI generation can take time |
| Port | 8000 | Standard Flask port |
| Bind | 0.0.0.0 | Accept external connections |

### Building the Image

```bash
cd backend
docker build -t aws-lab-flask-demo:local .
```

### Running the Container

**Basic run:**
```bash
docker run -d --name flask-test-container -p 8000:8000 \
  --env-file .env aws-lab-flask-demo:local
```

**With logs:**
```bash
docker run -d --name flask-test-container -p 8000:8000 \
  --env-file .env aws-lab-flask-demo:local

docker logs flask-test-container -f
```

### Container Management

**Start/stop:**
```bash
docker start flask-test-container
docker stop flask-test-container
```

**View logs:**
```bash
docker logs flask-test-container --tail 50
docker logs flask-test-container -f  # Follow
```

**Remove container:**
```bash
docker stop flask-test-container
docker rm flask-test-container
```

**Rebuild after code changes:**
```bash
docker build -t aws-lab-flask-demo:local .
docker stop flask-test-container
docker rm flask-test-container
docker run -d --name flask-test-container -p 8000:8000 \
  --env-file .env aws-lab-flask-demo:local
```

---

## Discord Bot Integration

### Overview

The Discord bot (`test-discord-bot.py`) serves as a client application to test the backend API through Discord's chat interface.

**Location:** `../test-discord-bot.py` (project root)
**Size:** 275 lines
**Dependencies:** discord.py 2.3.2, aiohttp 3.9.1

### Bot Commands

| Command | Description | Example |
|---------|-------------|---------|
| `!health` | Check backend health | `!health` |
| `!image <prompt>` | Generate AI image | `!image a cute cat` |
| `!audio <prompt>` | Generate AI music | `!audio calm piano` |
| `!history` | View generation history | `!history` |
| `!commands` | Show help | `!commands` |
| `!ping` | Check bot latency | `!ping` |

### How It Works

1. **Bot connects to Discord** using `DISCORD_TOKEN`
2. **Listens for commands** with `!` prefix
3. **Makes HTTP requests** to backend API (`http://localhost:8000`)
4. **Displays results** as Discord embeds with images/links

### Example Flow: Image Generation

```
User types: !image a cute cat
     ↓
Bot receives command, extracts prompt
     ↓
Bot sends POST to http://localhost:8000/generate-image
     ↓
Backend generates image, uploads to S3, returns URL
     ↓
Bot creates Discord embed with image
     ↓
User sees generated image in Discord
```

### Starting the Bot

**Method 1: Manual**
```bash
cd ..  # Go to project root
python test-discord-bot.py
```

**Method 2: Automated (Recommended)**
```bash
cd backend
bash start-discord-test.sh
# or
start-discord-test.bat
```

### Bot Configuration

The bot loads configuration from `backend/.env`:

```python
# Load from backend/.env
backend_env = Path(__file__).parent / "backend" / ".env"
if backend_env.exists():
    load_dotenv(backend_env)

DISCORD_TOKEN = os.getenv("DISCORD_TOKEN") or os.getenv("DISCORD_BOT_TOKEN")
API_BASE_URL = os.getenv("API_GATEWAY_URL", "http://localhost:8000")
```

### Discord Embed Limits

Discord has strict limits on embed field values (1024 characters). The bot handles this by:

- Truncating long S3 presigned URLs
- Using footer text for URL display
- Combining fields to reduce total field count

**Fixed Issues:**
- ✅ Long presigned URLs no longer cause errors
- ✅ Embeds stay under 1024 character limit per field
- ✅ Images display inline instead of separate download links

---

## Development Workflow

### Local Development Cycle

**1. Make code changes**
```bash
# Edit backend/src/app.py or backend/src/db.py
```

**2. Run tests**
```bash
cd backend
pytest tests/ -v
```

**3. Rebuild Docker image**
```bash
docker build -t aws-lab-flask-demo:local .
```

**4. Restart container**
```bash
docker stop flask-test-container
docker rm flask-test-container
docker run -d --name flask-test-container -p 8000:8000 \
  --env-file .env aws-lab-flask-demo:local
```

**5. Test with Discord bot**
```bash
bash start-discord-test.sh
# Test in Discord: !health, !image test, etc.
```

### Quick Testing Shortcuts

**Test backend directly:**
```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/generate-image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","user_id":"test"}'
```

**Automated testing:**
```bash
# Use the startup script for fastest testing
cd backend
bash start-discord-test.sh
```

### AWS Credential Refresh Workflow

**When credentials expire (every 3-4 hours):**

1. Go to AWS Learner Lab
2. Click "Start Lab"
3. Click "AWS Details" → "Show" next to AWS CLI
4. Copy credentials
5. Update `backend/.env`
6. Recreate container:
   ```bash
   docker stop flask-test-container
   docker rm flask-test-container
   docker run -d --name flask-test-container -p 8000:8000 \
     --env-file .env aws-lab-flask-demo:local
   ```

---

## Troubleshooting

### Common Issues

#### 1. Discord Bot: "ModuleNotFoundError: No module named 'discord'"

**Problem:** discord.py not installed in active Python environment

**Solution:**
```bash
pip install discord.py aiohttp
```

**Note:** The startup scripts now automatically detect which Python has discord.py installed.

---

#### 2. Backend: "ExpiredToken" error when uploading to S3

**Problem:** AWS Learner Lab credentials expired (normal, happens every 3-4 hours)

**Solution:**
1. Refresh credentials from AWS Learner Lab
2. Update `backend/.env`
3. Recreate Docker container (restart isn't enough)

```bash
docker stop flask-test-container
docker rm flask-test-container
docker run -d --name flask-test-container -p 8000:8000 \
  --env-file .env aws-lab-flask-demo:local
```

---

#### 3. Image Generation: DynamoDB "ResourceNotFoundException"

**Problem:** DynamoDB table `UserRecords` doesn't exist

**Impact:** Images still generate successfully (DynamoDB error is non-fatal)

**Solution (if you want history tracking):**
1. Go to AWS Console → DynamoDB
2. Create table:
   - Table name: `UserRecords`
   - Partition key: `user_id` (String)
   - Sort key: `record_id` (String)

---

#### 4. Audio Generation: "Insufficient credits"

**Problem:** Suno API account needs credits

**Solution:**
1. Go to Suno API website
2. Top up credits
3. Update `SUNO_TOKEN` in `.env` if needed
4. Recreate container

---

#### 5. Docker: "Container already exists"

**Problem:** Old container with same name exists

**Solution:**
```bash
docker stop flask-test-container
docker rm flask-test-container
# Then create new container
```

**Note:** The startup scripts handle this automatically.

---

#### 6. Discord: "Invalid Form Body: Must be 1024 or fewer in length"

**Problem:** Discord embed field too long (usually presigned URLs)

**Status:** ✅ Fixed in test-discord-bot.py
- URLs are now truncated
- Embeds use footer instead of fields
- Images display inline

---

#### 7. Tests: Import errors

**Problem:** Running tests from wrong directory

**Solution:**
```bash
cd backend  # Make sure you're in backend directory
pytest tests/ -v
```

---

#### 8. Docker: Port already in use

**Problem:** Another process using port 8000

**Solution:**
```bash
# Find process using port 8000
netstat -ano | findstr :8000  # Windows
lsof -i :8000  # Mac/Linux

# Kill the process or use different port
docker run -d --name flask-test-container -p 8001:8000 \
  --env-file .env aws-lab-flask-demo:local
```

---

### Debugging Commands

**Check container status:**
```bash
docker ps -a --filter "name=flask-test-container"
```

**View container logs:**
```bash
docker logs flask-test-container --tail 100
docker logs flask-test-container -f  # Follow
```

**Test backend directly:**
```bash
curl -v http://localhost:8000/health
```

**Check which Python has discord.py:**
```bash
python -c "import discord; print('OK')"
python3 -c "import discord; print('OK')"
```

**Verify .env loaded in container:**
```bash
docker exec flask-test-container env | grep AWS
```

---

## Summary

This backend provides a production-ready AI generation service with:

✅ **RESTful API** - Flask 3.0.0 with Gunicorn
✅ **AI Integration** - HuggingFace (images) + Suno (audio)
✅ **Cloud Storage** - AWS S3 with presigned URLs
✅ **History Tracking** - AWS DynamoDB (optional)
✅ **Containerization** - Docker with Lambda Web Adapter
✅ **Testing** - 17 comprehensive tests
✅ **Client Integration** - Discord bot for testing
✅ **Automation** - Startup scripts for easy testing
✅ **Documentation** - Complete API and setup docs

**Ready for:**
- Local development and testing
- Docker deployment
- AWS Lambda deployment (via SAM/Jenkins CI/CD)
- Discord bot integration
- Production use

---

**Last Updated:** 2025-12-10
**Version:** 1.0
**Status:** Production Ready ✅
