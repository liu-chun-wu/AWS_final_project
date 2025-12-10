# Jenkins Blue Ocean Setup Guide

Complete guide for setting up Jenkins with Blue Ocean for the AWS Flask CI/CD Demo project.

## 🎯 What is Blue Ocean?

Blue Ocean is Jenkins' modern, visual UI that provides:
- **Visual Pipeline Editor** - Create and edit pipelines graphically
- **Beautiful Visualization** - See your pipeline stages flow in real-time
- **Better Feedback** - Clear success/failure indicators with timing
- **Branch & PR Support** - Better Git workflow visualization
- **Intuitive Navigation** - Modern, user-friendly interface

---

## 📋 Prerequisites

✅ **Jenkins Running**: Container `jenkins-local` on port 8080
✅ **Admin Password**: `3d40dd0924b74e6a875e270b0388e8a4`
✅ **Project Committed**: All code in Git repository

---

## 🚀 Step-by-Step Setup

### Step 1: Access Jenkins

1. **Open Jenkins in your browser**:
   ```
   http://localhost:8080
   ```

2. **You should see**: "Unlock Jenkins" page with password field

---

### Step 2: Unlock Jenkins

1. **Enter Admin Password**:
   ```
   3d40dd0924b74e6a875e270b0388e8a4
   ```

2. **Click "Continue"**

---

### Step 3: Install Plugins

**IMPORTANT**: We need both suggested plugins AND Blue Ocean

#### Option A: Install Suggested Plugins First (Recommended)

1. **Click "Install suggested plugins"**
   - Wait 2-3 minutes for installation
   - You'll see progress bars for ~89 plugins

2. **After completion**, go to:
   - "Manage Jenkins" (left sidebar)
   - "Plugins" (or "Manage Plugins")
   - Click "Available plugins" tab
   - Search for: **"Blue Ocean"**
   - ☑ Check "Blue Ocean" plugin
   - Click "Install without restart"
   - Wait for installation to complete
   - **Restart Jenkins** when prompted

#### Option B: Select Custom Plugins

1. **Click "Select plugins to install"**
2. **Search and select**:
   - Blue Ocean (all related plugins)
   - Docker Pipeline
   - Git plugin
   - Pipeline
   - Pipeline: Stage View
   - Workspace Cleanup
3. **Click "Install"**

---

### Step 4: Create Admin User (Optional)

You can either:

**Option A: Create Admin User**
- Username: `admin` (or your preference)
- Password: (choose a strong password)
- Full Name: `Jenkins Admin`
- Email: your@email.com
- Click "Save and Continue"

**Option B: Continue as Admin**
- Click "Continue as admin"
- Use initial password for future logins

---

### Step 5: Instance Configuration

1. **Jenkins URL**: Keep default
   ```
   http://localhost:8080/
   ```

2. **Click "Save and Finish"**

3. **Click "Start using Jenkins"**

---

## 🌊 Access Blue Ocean

### Method 1: From Classic UI

1. **Look for "Open Blue Ocean"** in the left sidebar
2. **Click it** - You'll be taken to Blue Ocean interface

### Method 2: Direct URL

Navigate to:
```
http://localhost:8080/blue
```

---

## 🔧 Create Pipeline in Blue Ocean

### Step 1: Create New Pipeline

1. **In Blue Ocean**, click **"Create a new Pipeline"**

2. **Where do you store your code?**
   - Select **"Git"** (not GitHub, just Git)

3. **Repository URL**:
   ```
   /Users/jeffery.liu/Projects/AWS_final_project
   ```

   **Note**: Use the absolute path to your local repository

4. **Click "Create Pipeline"**

Blue Ocean will automatically:
- Scan your repository
- Find the `ci/Jenkinsfile`
- Create the pipeline configuration
- Show you the pipeline structure

---

### Step 2: Understanding the Blue Ocean Interface

You should see your pipeline with 5 stages:

```
┌───────────┐   ┌────────────┐   ┌──────────┐   ┌──────────┐   ┌─────────────┐
│ Checkout  │ → │   Setup    │ → │ Install  │ → │   Test   │ → │    Build    │
│           │   │   Python   │   │   Deps   │   │          │   │   Docker    │
└───────────┘   └────────────┘   └──────────┘   └──────────┘   └─────────────┘
```

**Interface Elements:**
- **Run button** (top right) - Trigger a build
- **Branches** - Shows all Git branches
- **Activity** - Build history
- **Pipeline** - Visual pipeline view

---

## ▶️ Run Your First Build

### Step 1: Trigger Build

1. **Click the "Run" button** (top right, play icon)
2. **Watch the visual pipeline execute**

### Step 2: Monitor Progress

You'll see each stage:

**Stage 1: Checkout** (~2-5 seconds)
- Cloning repository
- Blue progress bar

**Stage 2: Setup Python Environment** (~10-15 seconds)
- Creating virtual environment
- Installing pip

**Stage 3: Install Dependencies** (~5-10 seconds)
- Installing Flask, gunicorn, pytest
- Blue Ocean shows logs in real-time

**Stage 4: Run Tests** (~3-5 seconds)
- Running 18 tests (5 unit + 13 integration)
- **You'll see**: "All tests passed successfully"
- Green checkmark when complete

**Stage 5: Build Docker Image** (~30-60 seconds)
- Building Docker image
- Tagging with build number
- **Result**: `aws-lab-flask-demo:1` created

### Step 3: View Results

**If Successful (Blue/Green):**
- All 5 stages show ✓ checkmarks
- Total duration displayed (~1-2 minutes)
- Build marked as successful

**If Failed (Red):**
- Failed stage highlighted in red
- Click stage to see error logs
- Fix issue and rerun

---

## 📊 Blue Ocean Features You'll See

### 1. Visual Pipeline View

Each stage is represented as a box:
- **Blue** = Running
- **Green** = Success
- **Red** = Failed
- **Gray** = Not started/Skipped

### 2. Stage Logs

**Click any stage** to see:
- Console output for that specific stage
- Timing information
- Step-by-step execution

### 3. Test Results

In the "Test" stage, you'll see:
- Total tests run: 18
- Passed: 18
- Failed: 0
- Duration: ~3 seconds

### 4. Artifacts

After build completes:
- Docker image created
- Build tagged with build number
- Logs available for download

### 5. Branch View

See all branches:
- `main` branch
- `Jeffery` branch (your current work)
- Each with separate build history

---

## ✅ Verify Pipeline Success

### Check 1: Blue Ocean UI

All 5 stages should show:
- ✓ Checkout (2-5s)
- ✓ Setup Python Environment (10-15s)
- ✓ Install Dependencies (5-10s)
- ✓ Run Tests (3-5s) - **18/18 tests passed**
- ✓ Build Docker Image (30-60s)

**Total Duration**: Should be < 2 minutes

### Check 2: Docker Image Created

Open terminal and run:
```bash
docker images aws-lab-flask-demo
```

You should see:
```
REPOSITORY           TAG       IMAGE ID       CREATED          SIZE
aws-lab-flask-demo   1         xxxxxxxxxxxx   2 minutes ago    242MB
aws-lab-flask-demo   latest    xxxxxxxxxxxx   2 minutes ago    242MB
```

**Note**: Build number (1, 2, 3...) tags are created by Jenkins

### Check 3: Build Artifacts

In Blue Ocean, click on the build:
- See "Artifacts" tab
- Docker image information
- Test results
- Console logs

---

## 🧪 Test Pipeline Failure (Important Validation)

To ensure your pipeline fails correctly when tests break:

### Step 1: Intentionally Break a Test

1. **Edit file**: `backend/tests/unit/test_health.py`

2. **Find line 24**:
   ```python
   assert response.status_code == 200
   ```

3. **Change to** (intentionally wrong):
   ```python
   assert response.status_code == 500
   ```

4. **Save and commit**:
   ```bash
   git add backend/tests/unit/test_health.py
   git commit -m "Test: Intentionally break health test"
   ```

### Step 2: Run Pipeline Again

1. **In Blue Ocean**, click "Run"
2. **Watch the pipeline**:
   - ✓ Checkout - Success
   - ✓ Setup Python Environment - Success
   - ✓ Install Dependencies - Success
   - **❌ Run Tests** - **FAILED** (This is expected!)
   - ⊘ Build Docker Image - Skipped (not reached)

### Step 3: View Failure

1. **Click the failed "Run Tests" stage**
2. **You'll see**:
   ```
   FAILED tests/unit/test_health.py::test_health_endpoint_returns_200
   AssertionError: assert 200 == 500
   ```

3. **Pipeline marked as FAILED** - This is correct behavior!

### Step 4: Fix the Test

1. **Revert the change**:
   ```python
   assert response.status_code == 200  # Fixed!
   ```

2. **Commit the fix**:
   ```bash
   git add backend/tests/unit/test_health.py
   git commit -m "Fix: Restore correct health test assertion"
   ```

3. **Run pipeline again** - Should succeed!

**Why This is Important**:
- Ensures your CI/CD catches real errors
- Validates pipeline fail-fast behavior
- Tests before expensive Docker build

---

## 🎨 Blue Ocean vs Classic Jenkins

### When to Use Blue Ocean

✅ **Viewing pipeline runs** - Much clearer visualization
✅ **Monitoring builds** - Real-time stage progress
✅ **Debugging failures** - Better log segregation
✅ **Learning Jenkins** - More intuitive interface
✅ **Git branch workflows** - Better branch/PR view

### When to Use Classic UI

✅ **System administration** - Plugin management, security
✅ **Advanced configuration** - Some settings not in Blue Ocean
✅ **Scripted Pipelines** - Full Groovy script editing
✅ **Jenkins Management** - User management, system config

**You can switch between both anytime:**
- Classic: http://localhost:8080
- Blue Ocean: http://localhost:8080/blue

---

## 🔧 Troubleshooting

### Issue 1: Blue Ocean Not Showing

**Problem**: "Open Blue Ocean" not in sidebar

**Solution**:
1. Go to "Manage Jenkins" → "Plugins"
2. Search "Blue Ocean"
3. Install "Blue Ocean" plugin
4. Restart Jenkins
5. Refresh browser

---

### Issue 2: Pipeline Not Found

**Problem**: Blue Ocean can't find Jenkinsfile

**Solution**:
1. Verify `ci/Jenkinsfile` exists in your repo
2. Check file path is correct: `ci/Jenkinsfile`
3. Commit and push if not committed
4. Rescan repository in Blue Ocean

---

### Issue 3: Python Not Found

**Problem**: "python3: command not found"

**Solution**:
Your Jenkinsfile uses `python3`. If Jenkins container doesn't have Python:
1. Install Python in Jenkins container, OR
2. Use Jenkins agent with Python installed, OR
3. Modify Jenkinsfile to use Docker-in-Docker approach

---

### Issue 4: Docker Socket Permission

**Problem**: "permission denied while trying to connect to Docker"

**Solution**:
```bash
# Give Jenkins access to Docker socket
docker exec -u root jenkins-local chmod 666 /var/run/docker.sock
```

---

### Issue 5: Tests Fail in Jenkins but Pass Locally

**Problem**: Environment differences

**Solution**:
1. Check Python version (should be 3.11)
2. Verify all dependencies installed
3. Check file paths are correct
4. Review console logs for specific errors

---

## 📚 Next Steps After Successful Build

Once your pipeline succeeds:

1. **✅ Phase 3 Complete**: Jenkins CI/CD operational
2. **📊 Build History**: Track builds over time
3. **🔄 Automatic Triggers**: Set up webhook for auto-builds
4. **🚀 AWS Deployment**: Proceed to Phase 4
5. **📝 Documentation**: Update project docs with results

---

## 🎯 Success Criteria

Your Jenkins Blue Ocean setup is successful when:

✅ Blue Ocean interface accessible at http://localhost:8080/blue
✅ Pipeline created from Git repository
✅ First build completes successfully (~2 minutes)
✅ All 5 stages show green checkmarks
✅ 18/18 tests pass in "Run Tests" stage
✅ Docker image `aws-lab-flask-demo:1` created
✅ Test failure case validated (pipeline fails correctly)
✅ Fixed build succeeds again

---

## 🆘 Need Help?

**Common Commands**:

```bash
# View Jenkins logs
docker logs jenkins-local

# Restart Jenkins
docker restart jenkins-local

# Check running containers
docker ps

# View built images
docker images aws-lab-flask-demo

# Access Jenkins container shell
docker exec -it jenkins-local /bin/bash
```

**Jenkins URLs**:
- Classic UI: http://localhost:8080
- Blue Ocean: http://localhost:8080/blue
- Pipeline: http://localhost:8080/blue/organizations/jenkins/[pipeline-name]

---

## 🔔 Webhook Automation (GitHub → Jenkins)

### Overview

Automatically trigger Jenkins builds when pushing to the Jeffery branch using GitHub webhooks + ngrok.

**Why Webhooks?**
- ✅ Instant builds on every commit
- ✅ No manual "Run" button clicking
- ✅ Real-time CI/CD feedback
- ✅ Better developer experience

---

### Prerequisites

- ✅ Jenkins running locally on port 8080
- ✅ GitHub repository with admin access
- ✅ ngrok installed (`brew install ngrok`)
- ✅ GitHub Personal Access Token created

---

### Setup Steps

#### 1. Start ngrok Tunnel

```bash
# Configure ngrok (one-time)
ngrok config add-authtoken YOUR_NGROK_TOKEN

# Start tunnel (keep running)
ngrok http 8080
```

**Copy the HTTPS forwarding URL:**
```
Forwarding: https://xxxx-xxxx-xxxx.ngrok-free.dev -> http://localhost:8080
```

**Important:** Keep the ngrok terminal window open! If you close it, the URL will stop working.

---

#### 2. Configure GitHub Webhook

1. **Go to:** https://github.com/YOUR-USERNAME/AWS_final_project
2. **Settings** → **Webhooks** → **Add webhook**
3. **Payload URL:** `https://YOUR-NGROK-URL.ngrok-free.dev/github-webhook/`
   - ⚠️ Must end with `/github-webhook/` (trailing slash required!)
4. **Content type:** `application/json`
5. **Secret:** Leave blank
6. **Events:** Select "Let me select individual events"
   - ☑ **Pushes** only
   - ☐ Uncheck all others
7. ☑ **Active**
8. **Add webhook**

**Verify:** Should see green checkmark and "Ping" delivery status 200 OK

---

#### 3. Enable Webhook Trigger in Jenkins

1. **Jenkins** → Your pipeline → **Configure**
2. **Build Triggers** section
3. ☑ Check: **"GitHub hook trigger for GITScm polling"**
4. **Save**

---

#### 4. Branch Filtering (Already Configured)

The Jenkinsfile includes a "Branch Check" stage that ensures only Jeffery branch builds proceed:

```groovy
stage('Branch Check') {
    steps {
        script {
            def branchName = env.GIT_BRANCH ?: 'unknown'
            if (!branchName.contains('Jeffery')) {
                currentBuild.result = 'NOT_BUILT'
                error("Skipping build: This pipeline only runs on Jeffery branch")
            }
            echo "✅ Branch check passed"
        }
    }
}
```

**Behavior:**
- Push to `Jeffery` → Build runs all 6 stages
- Push to `main` → Build skips after "Branch Check"
- Push to `feature/*` → Build skips after "Branch Check"

---

### Testing the Webhook

```bash
# Make sure you're on Jeffery branch
git checkout Jeffery

# Make a test change
echo "# Test webhook" >> README.md

# Commit and push
git add README.md
git commit -m "Test: Webhook automation"
git push origin Jeffery
```

**Expected Result:**
- Jenkins starts building **immediately** (within 2-3 seconds)
- Blue Ocean shows new build in activity feed
- All 6 stages execute (Checkout → Branch Check → Setup → Install → Test → Build)
- Total time: ~2 minutes
- Docker image `aws-lab-flask-demo:X` created

---

### Troubleshooting Webhooks

#### Webhook shows 403 or 404 error

**Problem:** GitHub can't reach Jenkins

**Solutions:**
```bash
# 1. Verify ngrok is running
# Check ngrok terminal - should show "Session Status: online"

# 2. Test ngrok URL in browser
# Open: https://your-ngrok-url.ngrok-free.dev
# Should show Jenkins login page

# 3. Verify webhook URL ends with /github-webhook/
# Correct:   https://xxxx.ngrok-free.dev/github-webhook/
# Incorrect: https://xxxx.ngrok-free.dev/github-webhook
```

---

#### Webhook delivers but Jenkins doesn't build

**Problem:** Webhook trigger not enabled

**Solutions:**
1. Jenkins → Pipeline → Configure
2. Check: ☑ "GitHub hook trigger for GITScm polling"
3. Save and retry

---

#### ngrok URL expired or changed

**Problem:** Free ngrok URLs change on restart

**What happened:**
- ngrok session ended (timeout, computer sleep, etc.)
- New ngrok session = new URL

**Solution:**
```bash
# 1. Restart ngrok
ngrok http 8080

# 2. Copy new URL

# 3. Update GitHub webhook
# Settings → Webhooks → Edit → Update Payload URL → Update webhook
```

**To avoid this:** Keep ngrok running continuously, or upgrade to ngrok paid plan for static URL

---

#### Build triggers for wrong branch

**Check:**
1. View build logs in Blue Ocean
2. Look for "Branch Check" stage
3. Should show: "Current branch: origin/Jeffery"
4. If wrong branch, Jenkinsfile will exit early

**Verify Jenkinsfile:**
```groovy
if (!branchName.contains('Jeffery')) {
    error("Skipping build...")  // Non-Jeffery branches stop here
}
```

---

### Webhook Best Practices

**✅ Do:**
- Keep ngrok terminal running during development
- Test webhook after setup (make a commit)
- Check "Recent Deliveries" in GitHub webhook settings
- Monitor Jenkins build queue for auto-triggered builds

**❌ Don't:**
- Close ngrok terminal (will break webhook)
- Forget trailing slash in webhook URL
- Use webhook for production (upgrade to EC2-hosted Jenkins)
- Expose sensitive data in public ngrok URL

---

### Alternative: SCM Polling (No Webhook)

If ngrok is not available, use SCM polling:

**Jenkins Configuration:**
1. Pipeline → Configure
2. Build Triggers → ☑ "Poll SCM"
3. Schedule: `H/15 * * * *` (every 15 minutes)
4. Save

**Pros:** Works without ngrok
**Cons:** 15-minute delay, higher GitHub API usage

---

### ngrok Session Management

**Keep ngrok running:**
```bash
# Option 1: Dedicated terminal
# Just keep the terminal open

# Option 2: Run in background (macOS/Linux)
nohup ngrok http 8080 > ngrok.log 2>&1 &

# View log
tail -f ngrok.log

# Stop ngrok
pkill ngrok
```

**Check ngrok status:**
```bash
# View all active tunnels
curl http://localhost:4040/api/tunnels | jq

# Web UI
open http://localhost:4040
```

---

### Webhook Payload Example

When you push to GitHub, it sends this to Jenkins:

```json
{
  "ref": "refs/heads/Jeffery",
  "repository": {
    "name": "AWS_final_project",
    "full_name": "liu-chun-wu/AWS_final_project"
  },
  "pusher": {
    "name": "liu-chun-wu"
  },
  "commits": [...]
}
```

Jenkins parses `ref` to determine branch and triggers build if "GitHub hook trigger" is enabled.

---

## 📖 Additional Resources

- **Blue Ocean Documentation**: https://www.jenkins.io/doc/book/blueocean/
- **Pipeline Syntax**: https://www.jenkins.io/doc/book/pipeline/syntax/
- **Docker in Jenkins**: https://www.jenkins.io/doc/book/pipeline/docker/
- **Jenkinsfile Examples**: https://www.jenkins.io/doc/pipeline/examples/

---

**Ready to proceed?** Follow the steps above and let me know when you reach each checkpoint!
