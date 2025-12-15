# Discord Bot Testing Guide

Complete guide for testing the NeoYeh AI Generation Backend integration with Discord bot.

**Last Updated:** 2025-12-10
**Status:** Integration Complete ✅

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Start the Backend](#1-start-the-backend-docker-container)
3. [Start the Discord Bot](#2-start-the-discord-bot)
4. [Discord Bot Test Commands](#3-discord-bot-test-commands)
5. [Troubleshooting Commands](#4-troubleshooting-commands)
6. [Testing Workflow](#5-testing-workflow)
7. [Current Status](#6-current-status)

---

## Prerequisites

- ✅ Docker Desktop running
- ✅ AWS credentials updated in `backend/.env`
- ✅ Discord bot token in `backend/.env`
- ✅ Backend Docker image built (`aws-lab-flask-demo:local`)
- ✅ Python environment with discord.py installed

**Required Environment Variables in `backend/.env`:**
```env
# AWS Credentials (from AWS Learner Lab)
AWS_ACCESS_KEY_ID=<your_key>
AWS_SECRET_ACCESS_KEY=<your_secret>
AWS_SESSION_TOKEN=<your_token>
AWS_DEFAULT_REGION=us-east-1

# S3 Bucket
S3_BUCKET_NAME=tmp-230909

# DynamoDB Table (optional)
DYNAMODB_TABLE=UserRecords

# AI API Tokens
HUGGINGFACE_TOKEN=<your_token>
SUNO_TOKEN=<your_token>

# Discord Bot Token
DISCORD_TOKEN=<your_bot_token>
DISCORD_BOT_TOKEN=<your_bot_token>
```

---

## 1. Start the Backend (Docker Container)

### Start Fresh Container
```bash
docker run -d --name flask-test-container -p 8000:8000 --env-file "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2/backend/.env" aws-lab-flask-demo:local
```

### Restart Existing Container
```bash
docker restart flask-test-container
```

### Stop Container
```bash
docker stop flask-test-container
```

### Remove Container (if you need to recreate)
```bash
docker stop flask-test-container
docker rm flask-test-container
```

### Verify Backend is Running
```bash
curl http://localhost:8000/health
```

**Expected output:**
```json
{"service":"production-backend","status":"ok"}
```

---

## 2. Start the Discord Bot

### Start Discord Bot
```bash
cd "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2"
python test-discord-bot.py
```

**Expected output:**
```
Starting Discord bot...
Backend API: http://localhost:8000
[2025-12-10 09:18:38] [INFO] discord.client: logging in using static token
[2025-12-10 09:18:39] [INFO] discord.gateway: Shard ID None has connected to Gateway (Session ID: ...)
```

### Stop Discord Bot
Press `Ctrl+C` in the terminal where the bot is running.

---

## 3. Discord Bot Test Commands

### 3.1 Health Check
Test if the backend is running and responding.

**Command:**
```
!health
```

**Expected Result:**
```
✅ Backend is healthy!
```json
{"service": "production-backend", "status": "ok"}
```
```

**What this tests:**
- Discord bot → Backend communication ✅
- Backend container is running ✅
- Basic API functionality ✅

---

### 3.2 Generate AI Image ⭐ (Primary Test)
Generate an image using HuggingFace Stable Diffusion XL.

**Command:**
```
!image a cute cat
```

**Other Examples:**
```
!image a beautiful sunset over mountains
!image cyberpunk city at night, neon lights
!image realistic portrait of a wizard with magic staff
!image peaceful Japanese garden with cherry blossoms
!image futuristic spaceship interior
!image abstract art with vibrant colors
```

**Expected Result:**
- ✅ Discord embed with title "✅ Image Generated!"
- Image displayed directly in Discord
- Footer with truncated download URL
- Generation time: ~10-15 seconds

**What this tests:**
- Discord bot → Backend API ✅
- HuggingFace API integration ✅
- Image generation ✅
- S3 upload ✅
- Presigned URL generation ✅
- Discord embed with image ✅

**Note:** DynamoDB history tracking will fail silently (table doesn't exist), but image generation still succeeds.

---

### 3.3 Generate AI Music
Generate music using Suno API (requires Suno credits).

**Command:**
```
!audio calm piano music
```

**Other Examples:**
```
!audio upbeat rock song
!audio relaxing ambient sounds
!audio epic orchestral music
```

**Expected Result (without credits):**
```
❌ Failed to generate audio:
Suno API 錯誤: The current credits are insufficient. Please top up.
```

**Expected Result (with credits):**
- ✅ Music Generation Started! embed
- Task ID provided
- Status: Processing
- Download link (will be available when ready)
- Note: Audio generation is async (1-2 minutes)

**What this tests:**
- Suno API integration ✅
- Async workflow handling ✅
- Error handling ✅

---

### 3.4 View Generation History
View your past image/audio generations (requires DynamoDB table).

**Command:**
```
!history
```

**Expected Result (without DynamoDB table):**
Error message about DynamoDB ResourceNotFoundException (expected).

**Expected Result (with DynamoDB table):**
- 📜 Your Generation History embed
- List of recent generations
- Prompt and download links
- Shows last 5 records

**What this tests:**
- DynamoDB query ✅
- History retrieval ✅

---

### 3.5 Show Available Commands
List all bot commands.

**Command:**
```
!commands
```

**Expected Result:**
Help message showing all available commands:
- !health
- !image
- !audio
- !history
- !commands
- !ping

---

### 3.6 Check Bot Latency
Test bot response time.

**Command:**
```
!ping
```

**Expected Result:**
```
🏓 Pong! Latency: XX ms
```

---

## 4. Troubleshooting Commands

### Check Docker Container Status
```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Check specific container
docker ps -a --filter "name=flask-test-container"
```

### View Backend Logs
```bash
# View last 50 lines
docker logs flask-test-container --tail 50

# View logs in real-time (follow)
docker logs flask-test-container -f

# Search logs for errors
docker logs flask-test-container 2>&1 | grep -i error
```

### Rebuild Docker Image (after code changes)
```bash
cd "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2/backend"
docker build -t aws-lab-flask-demo:local .
```

### Recreate Container with Updated Code
```bash
# Stop and remove old container
docker stop flask-test-container
docker rm flask-test-container

# Create new container with updated image
docker run -d --name flask-test-container -p 8000:8000 --env-file "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2/backend/.env" aws-lab-flask-demo:local
```

### Recreate Container with Updated .env
```bash
# Stop and remove container
docker stop flask-test-container
docker rm flask-test-container

# Recreate with new .env file
docker run -d --name flask-test-container -p 8000:8000 --env-file "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2/backend/.env" aws-lab-flask-demo:local

# Verify new credentials loaded
sleep 3
curl http://localhost:8000/health
```

### Test Backend Directly (without Discord)
```bash
# Test health endpoint
curl http://localhost:8000/health

# Test image generation
curl -X POST http://localhost:8000/generate-image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"a cute cat","user_id":"test_user"}'

# Test with formatted output
curl -s -X POST http://localhost:8000/generate-image \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test","user_id":"test"}' | python -m json.tool
```

---

## 5. Testing Workflow

### Quick Start (Everything in Order)

**Step 1: Start Backend**
```bash
docker run -d --name flask-test-container -p 8000:8000 --env-file "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2/backend/.env" aws-lab-flask-demo:local
```

**Step 2: Verify Backend**
```bash
# Wait 3-5 seconds for container to start
sleep 5

# Test health endpoint
curl http://localhost:8000/health
```

**Step 3: Start Discord Bot** (in a new terminal)
```bash
cd "D:/ncu/雲端/AWS_final_project/AWS_final_project-Jeffery_2"
python test-discord-bot.py
```

**Step 4: Test in Discord**
```
!health
!image a cute cat
!ping
```

### Clean Shutdown

**Step 1: Stop Discord Bot**
- Press `Ctrl+C` in the terminal running the bot

**Step 2: Stop Backend**
```bash
docker stop flask-test-container
```

**Optional: Remove Container**
```bash
docker rm flask-test-container
```

---

## 6. Current Status

### ✅ Fully Working

| Component | Status | Notes |
|-----------|--------|-------|
| Backend API | ✅ Working | Flask + Gunicorn on port 8000 |
| Docker Container | ✅ Working | `flask-test-container` |
| Discord Bot | ✅ Working | Connected to Discord Gateway |
| HuggingFace API | ✅ Working | Stable Diffusion XL image generation |
| AWS S3 Upload | ✅ Working | Images uploaded to `tmp-230909` bucket |
| Presigned URLs | ✅ Working | S3 download links generated |
| Error Handling | ✅ Working | Proper error messages returned |
| `!health` command | ✅ Working | Backend connectivity verified |
| `!image` command | ✅ Working | Full image generation workflow |
| `!ping` command | ✅ Working | Bot latency check |
| `!commands` command | ✅ Working | Help message display |

### ⚠️ Needs Setup (Optional Features)

| Component | Status | Required For | Solution |
|-----------|--------|--------------|----------|
| DynamoDB Table | ⚠️ Not Created | `!history` command | Create `UserRecords` table in AWS |
| Suno API Credits | ⚠️ Insufficient | `!audio` command | Top up Suno account |

### 🔧 Known Issues & Fixes

#### Issue: AWS Credentials Expired
**Symptom:** `ExpiredToken` error when uploading to S3
**Solution:**
1. Go to AWS Learner Lab
2. Click "Start Lab"
3. Copy new credentials
4. Update `backend/.env`
5. Recreate container: `docker stop flask-test-container && docker rm flask-test-container && docker run -d --name flask-test-container -p 8000:8000 --env-file "..." aws-lab-flask-demo:local`

#### Issue: Discord Embed Too Long
**Symptom:** `Invalid Form Body: Must be 1024 or fewer in length`
**Solution:** Fixed - URLs are now truncated to fit Discord's limits

#### Issue: NoneType Error on Audio Generation
**Symptom:** `'NoneType' object has no attribute 'get'`
**Solution:** Fixed - Suno API error responses are now properly handled

#### Issue: DynamoDB ResourceNotFoundException
**Symptom:** Image generation returns error about DynamoDB table
**Solution:** Fixed - DynamoDB errors no longer fail image generation (history tracking is optional)

---

## 7. Test Priority

**Recommended Testing Order:**

1. ✅ **!health** - Verify backend connectivity (takes 1 second)
2. ✅ **!image a cute cat** - Main functionality test (takes 10-15 seconds)
3. ✅ **!ping** - Bot responsiveness (takes 1 second)
4. ⚠️ **!audio calm piano music** - Will show credit error (expected)
5. ⚠️ **!history** - Will show DynamoDB error (expected)

**The key test is `!image` - if that works, the integration is successful!** 🎉

---

## 8. Architecture Summary

### Components

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  Discord User   │ ──────> │  Discord Bot     │ ──────> │  Backend API    │
│  (!commands)    │         │ (test-discord-   │         │  (Flask Docker) │
│                 │ <────── │  bot.py)         │ <────── │  port 8000      │
└─────────────────┘         └──────────────────┘         └─────────────────┘
                                                                  │
                                    ┌─────────────────────────────┼─────────────────────────────┐
                                    │                             │                             │
                                    ▼                             ▼                             ▼
                            ┌───────────────┐           ┌─────────────────┐         ┌──────────────────┐
                            │ HuggingFace   │           │   AWS S3        │         │  AWS DynamoDB    │
                            │ Stable Diff.  │           │ (Image Storage) │         │  (History Track) │
                            │ XL API        │           │                 │         │  (Optional)      │
                            └───────────────┘           └─────────────────┘         └──────────────────┘
```

### Data Flow (Image Generation)

1. User sends `!image a cute cat` in Discord
2. Discord bot receives command
3. Bot sends POST request to `http://localhost:8000/generate-image`
4. Backend calls HuggingFace API to generate image
5. Backend uploads image to S3
6. Backend generates presigned download URL
7. Backend attempts to save record to DynamoDB (fails silently if table missing)
8. Backend returns success response with download URL
9. Discord bot displays image in embed
10. User sees generated image in Discord

### Test Results Summary

**Test Date:** 2025-12-10
**Total Tests:** 6 commands
**Passed:** 4/6 ✅
**Partial:** 2/6 ⚠️ (requires setup)

| Command | Status | Notes |
|---------|--------|-------|
| !health | ✅ PASS | Backend responds correctly |
| !image | ✅ PASS | Full workflow works (HuggingFace → S3) |
| !ping | ✅ PASS | Bot latency check works |
| !commands | ✅ PASS | Help message displays |
| !audio | ⚠️ PARTIAL | Returns proper error (needs Suno credits) |
| !history | ⚠️ PARTIAL | Returns error (needs DynamoDB table) |

---

## 9. Next Steps (Optional)

### To Enable Full History Tracking

**Create DynamoDB Table:**

1. Go to AWS Console → DynamoDB
2. Click "Create table"
3. Configure:
   - **Table name:** `UserRecords`
   - **Partition key:** `user_id` (String)
   - **Sort key:** `record_id` (String)
   - **Settings:** Use default settings
4. Click "Create table"
5. Wait for table to become "Active"
6. Test: `!history` in Discord

### To Enable Audio Generation

**Top Up Suno Credits:**

1. Go to Suno API website
2. Log in to your account
3. Purchase credits
4. Update `SUNO_TOKEN` in `backend/.env` if needed
5. Recreate Docker container
6. Test: `!audio calm piano music` in Discord

---

## 10. Maintenance

### Regular Tasks

**Daily (when using AWS Learner Lab):**
- Refresh AWS credentials (they expire after 3-4 hours)
- Restart Docker container after updating .env

**After Code Changes:**
- Rebuild Docker image
- Recreate container
- Test `!health` and `!image` commands

**When Discord Bot Updates:**
- Restart Discord bot (Ctrl+C and rerun)
- No container restart needed

### Backup Important Files

Before making changes, backup:
- `backend/src/app.py`
- `backend/src/db.py`
- `test-discord-bot.py`
- `backend/.env` (don't commit to git!)

---

## 11. Resources

### Documentation
- Backend API: `backend/README.md`
- Project Overview: `FILE_OVERVIEW.md`
- CI/CD Instructions: `CLAUDE.md`

### Scripts
- Test scripts: `scripts/local/test-local.sh`, `scripts/local/build-local.sh`
- Docker test: `test-docker-local.sh`
- Discord bot: `test-discord-bot.py`

### Important URLs
- Backend Health: http://localhost:8000/health
- S3 Bucket: https://tmp-230909.s3.amazonaws.com/
- Discord Developer Portal: https://discord.com/developers/applications

---

## 12. Success Criteria

**Integration is considered successful when:**

✅ Backend container starts without errors
✅ `!health` command returns backend status
✅ `!image` command generates and displays images
✅ Images are uploaded to S3
✅ Discord bot handles errors gracefully
✅ No crashes or unhandled exceptions

**All criteria met as of 2025-12-10** 🎉

---

## Contact & Support

For issues or questions about this integration:
- Check container logs: `docker logs flask-test-container`
- Review backend README: `backend/README.md`
- Test endpoints directly with curl (see Troubleshooting section)

**End of Guide**
