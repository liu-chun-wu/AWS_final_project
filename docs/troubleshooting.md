# Troubleshooting Guide

Common issues and solutions for the project.

## Table of Contents

- [Local Environment](#local-environment)
- [Docker Issues](#docker-issues)
- [Jenkins CI/CD](#jenkins-cicd)
- [AWS Deployment](#aws-deployment)
- [Application Issues](#application-issues)
- [Quick Diagnostics](#quick-diagnostics)

---

## Local Environment

### Python Module Errors

**Symptom:** `ModuleNotFoundError`

**Solution:**
```bash
cd backend
rm -rf .venv
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Tests Fail Locally

**Symptom:** pytest errors

**Solution:**
```bash
# Run with verbose output
cd backend
pytest tests/ -v --tb=short

# Run specific failing test
pytest tests/unit/test_health.py::test_specific -v
```

### Wrong Python Version

**Symptom:** Syntax errors or compatibility issues

**Solution:**
```bash
# Verify Python version (must be 3.11)
python --version

# Use explicit version
python3.11 -m venv .venv
```

---

## Docker Issues

### Docker Build Fails

**Symptom:** Build errors

**Solution:**
```bash
# Enable verbose mode
docker build -t aws-lab-flask-demo:local backend/ --progress=plain

# Clear cache and rebuild
docker system prune -a
docker build --no-cache -t aws-lab-flask-demo:local backend/
```

### Container Won't Start

**Symptom:** Container exits immediately

**Solution:**
```bash
# Check logs
docker logs flask-test-container

# Run interactively
docker run --rm -it -p 8000:8000 --env-file backend/.env aws-lab-flask-demo:local /bin/bash
```

### Port Already in Use

**Symptom:** `Error: Port 8000 is already in use`

**Solution:**
```bash
# Find process using port
lsof -i :8000

# Kill process
kill -9 <PID>

# Or use different port
docker run -p 8001:8000 ...
```

---

## Jenkins CI/CD

### Pipeline Stuck at Checkout

**Symptom:** Build hangs at checkout stage

**Solutions:**
1. Check GitHub connectivity
2. Verify SSH keys/HTTPS credentials
3. Check VPN/firewall settings

### Docker Permission Denied

**Symptom:** `permission denied` when running Docker

**Solution:**
```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### AWS Credential Errors

**Symptom:** `ExpiredToken` or credential errors

**Solutions:**

For local Jenkins:
```bash
# Refresh AWS credentials
aws configure
aws sts get-caller-identity
```

For EC2 Jenkins:
```bash
# Verify LabRole is attached
aws sts get-caller-identity
```

### Webhook Not Triggering

**Symptom:** Push doesn't start build

**Checklist:**
1. Webhook URL matches current EC2 IP
2. Port 8080 open in security group
3. Branch filter matches (Jeffery)
4. Jenkins is running

---

## AWS Deployment

### SAM Deployment Fails

**Symptom:** `sam deploy` errors

**Common causes:**

1. **IAM Role Issue:**
   - Verify `LabRole` in template.yaml
   - Learner Lab cannot create new IAM roles

2. **Missing ECR Image:**
   ```bash
   # Push image first
   ./scripts/jenkins/20-ci-build-and-push.sh --prod
   ```

3. **Template Validation:**
   ```bash
   sam validate -t aws/template.yaml
   ```

### API Returns 500

**Symptom:** HTTP 500 errors from deployed API

**Solution:**
```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/flask-prod-backend-FlaskDemoFunction-xxx --follow

# Common issues:
# - Missing environment variables
# - Invalid request payload
# - External API timeout
```

### AWS Credentials Expired

**Symptom:** `ExpiredToken` error

**Solution:**
1. Go to AWS Learner Lab
2. Click "Start Lab"
3. Copy new credentials
4. Update `~/.aws/credentials` or `backend/.env`
5. Verify: `aws sts get-caller-identity`
6. Recreate Docker container if using `.env`

### Delete Old Stack

```bash
# Delete demo stack
sam delete --config-file aws/samconfig-demo.toml --stack-name flask-demo-backend

# Delete prod stack
sam delete --config-file aws/samconfig-prod.toml --stack-name flask-prod-backend
```

---

## Application Issues

### HuggingFace API Error

**Symptom:** Image generation fails

**Solutions:**
1. Verify `HUGGINGFACE_TOKEN` in `.env`
2. Check token has correct permissions
3. Verify API endpoint is responding

### Suno API Error

**Symptom:** "Insufficient credits" error

**Solution:**
- Top up Suno account credits
- Update `SUNO_TOKEN` if changed

### DynamoDB Error

**Symptom:** `ResourceNotFoundException`

**Note:** This is non-fatal - images still generate successfully.

**To fix (optional):**
1. Create `UserRecords` table in DynamoDB
2. Partition key: `user_id` (String)
3. Sort key: `record_id` (String)

### Discord Embed Too Long

**Symptom:** `Invalid Form Body: Must be 1024 or fewer`

**Status:** Fixed in current version
- URLs are truncated automatically
- Images display inline

---

## Quick Diagnostics

### Check Everything at Once

```bash
# 1. Python environment
python --version
pip list | grep Flask

# 2. Docker
docker ps
docker images | grep aws-lab

# 3. AWS credentials
aws sts get-caller-identity

# 4. Backend health
curl http://localhost:8000/health

# 5. Run tests
./scripts/local/test-local.sh --prod
```

### Common Commands

| Issue | Command |
|-------|---------|
| View container logs | `docker logs flask-test-container` |
| Check ECR images | `aws ecr describe-images --repo aws-lab-flask-demo` |
| Check Lambda | `aws lambda get-function --function-name FlaskDemoFunction` |
| Tail CloudWatch | `aws logs tail /aws/lambda/... --follow` |
| Jenkins status | `./scripts/jenkins/91-check-jenkins-status.sh` |

### When All Else Fails

1. **Reproduce locally first** - use manual scripts before Jenkins
2. **Check logs** - Docker logs, CloudWatch logs, Jenkins console
3. **Verify credentials** - AWS tokens expire frequently
4. **Clean restart** - remove containers, rebuild images

---

## See Also

- [Testing Guide](TESTING.md)
- [CI/CD Pipeline](CI_CD.md)
- [Application Documentation](APPLICATION.md)
