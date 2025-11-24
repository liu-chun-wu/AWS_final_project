# Implementation Validation Checklist

Use this checklist to validate that the AWS Flask CI/CD project is working correctly at each phase.

## Phase 1: Local Flask Implementation

### Setup
- [ ] Python 3.11 installed: `python --version`
- [ ] Conda/virtualenv environment created
- [ ] Dependencies installed: `pip install -r backend/requirements.txt`

### Testing
```bash
cd backend
pytest tests/ -v
```
- [ ] All unit tests pass (test_health.py)
- [ ] All integration tests pass (test_echo.py)
- [ ] No test failures or errors

### Local Application
```bash
# Start application
cd backend
python src/app.py
```
- [ ] Application starts without errors
- [ ] Server running on http://localhost:8000

### Endpoint Validation
```bash
# Test /health endpoint
curl http://localhost:8000/health

# Expected response:
# {"status": "ok", "service": "demo-backend"}
```
- [ ] GET /health returns 200
- [ ] Response JSON contains "status": "ok"
- [ ] Response JSON contains "service": "demo-backend"

```bash
# Test /echo endpoint with valid JSON
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "test", "value": 123}'

# Expected response:
# {"body": {"message": "test", "value": 123}}
```
- [ ] POST /echo returns 200
- [ ] Response contains "body" field
- [ ] Body content matches request payload

```bash
# Test /echo with invalid JSON (should fail)
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d 'invalid json'

# Expected response:
# {"error": "Invalid JSON payload"} with 400 status
```
- [ ] Invalid JSON returns 400 status
- [ ] Error message is returned

```bash
# Test invalid HTTP method (should fail)
curl -X POST http://localhost:8000/health

# Expected: 405 Method Not Allowed
```
- [ ] Wrong HTTP method returns 405

**Phase 1 Checkpoint**: All tests pass, application runs locally, endpoints work correctly

---

## Phase 2: Docker Containerization

### Docker Build
```bash
docker build -t aws-lab-flask-demo:local backend/
```
- [ ] Build completes successfully
- [ ] Build time < 5 minutes
- [ ] No build errors

### Image Verification
```bash
docker images | grep aws-lab-flask-demo
```
- [ ] Image exists
- [ ] Image size < 300MB (target: ~150-200MB)

### Container Execution
```bash
docker run --rm -p 8000:8000 aws-lab-flask-demo:local
```
- [ ] Container starts successfully
- [ ] No runtime errors in logs
- [ ] Server accessible on port 8000

### Container Endpoint Testing
```bash
# Test /health endpoint
curl http://localhost:8000/health

# Test /echo endpoint
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"docker": "test"}'
```
- [ ] GET /health works in container
- [ ] POST /echo works in container
- [ ] Responses identical to local Python execution

### Container Logs
```bash
# Get container ID
docker ps

# View logs
docker logs <container-id>
```
- [ ] Logs show request/response activity
- [ ] No error messages in logs
- [ ] Gunicorn workers started successfully

**Phase 2 Checkpoint**: Docker image builds, container runs, endpoints work identically to local

---

## Phase 3: Jenkins CI Pipeline

### Jenkins Setup
```bash
# Start Jenkins
docker run -d --name jenkins-local \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get admin password
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword
```
- [ ] Jenkins container running
- [ ] Accessible at http://localhost:8080
- [ ] Initial setup completed
- [ ] Docker Pipeline plugin installed

### Pipeline Configuration
- [ ] Pipeline job created
- [ ] SCM configured with Git repository
- [ ] Branch specified (main or Jeffery)
- [ ] Jenkinsfile path set: `ci/Jenkinsfile`

### Pipeline Execution - Success Case
```
Trigger: Build Now
```
- [ ] Stage 1 (Checkout) - Success
- [ ] Stage 2 (Setup Python Environment) - Success
- [ ] Stage 3 (Install Dependencies) - Success
- [ ] Stage 4 (Run Tests) - Success
- [ ] Stage 5 (Build Docker Image) - Success
- [ ] Total execution time < 10 minutes
- [ ] Docker image created with build number tag

### Pipeline Execution - Failure Case
```python
# Intentionally break a test in backend/tests/unit/test_health.py
def test_health_endpoint_returns_200(client):
    response = client.get('/health')
    assert response.status_code == 500  # Changed from 200 to 500
```
- [ ] Commit broken test
- [ ] Trigger build
- [ ] Pipeline fails at "Run Tests" stage
- [ ] Build marked as failed (red)
- [ ] Subsequent stages not executed
- [ ] Error message visible in logs

```python
# Fix the test back
def test_health_endpoint_returns_200(client):
    response = client.get('/health')
    assert response.status_code == 200  # Fixed
```
- [ ] Commit fixed test
- [ ] Pipeline passes again

**Phase 3 Checkpoint**: Jenkins pipeline runs successfully, fails appropriately on broken tests

---

## Phase 4: AWS Deployment

### Prerequisites
- [ ] AWS Learner Lab session active
- [ ] AWS CLI configured: `aws sts get-caller-identity`
- [ ] AWS SAM CLI installed: `sam --version`
- [ ] Region set to us-east-1

### ECR Repository Setup
```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name aws-lab-flask-demo \
  --region us-east-1

# Note the repository URI
```
- [ ] ECR repository created
- [ ] Repository URI documented

### Manual Docker Push Test
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ECR-URI>

# Tag and push
docker tag aws-lab-flask-demo:local <ECR-URI>:test
docker push <ECR-URI>:test
```
- [ ] ECR authentication successful
- [ ] Image push successful
- [ ] Image visible in ECR console

### SAM Template Validation
```bash
cd aws
sam validate
```
- [ ] Template validation passes
- [ ] No syntax errors

### Manual SAM Deployment
```bash
cd aws
sam build
sam deploy --guided

# Follow prompts:
# Stack name: flask-demo-backend
# Region: us-east-1
# Confirm changes: Y
# Allow IAM role creation: Y
```
- [ ] SAM build successful
- [ ] CloudFormation stack created
- [ ] Lambda function deployed
- [ ] API Gateway created
- [ ] Outputs displayed (API URL, function ARN, log group)

### API Gateway Testing
```bash
# Get API URL from SAM outputs
API_URL="https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod"

# Test /health
curl ${API_URL}/health

# Test /echo
curl -X POST ${API_URL}/echo \
  -H "Content-Type: application/json" \
  -d '{"aws": "deployment", "test": true}'
```
- [ ] GET /health returns 200 from API Gateway
- [ ] Response JSON correct
- [ ] POST /echo returns 200
- [ ] Echo response correct
- [ ] Three consecutive successful requests to each endpoint

### CloudWatch Logs
```bash
# Get function name from outputs
aws logs tail /aws/lambda/<function-name> --follow
```
- [ ] Log group exists
- [ ] Logs contain request entries
- [ ] Timestamps are recent (< 5 minutes)
- [ ] Both /health and /echo requests logged

### Performance Testing
```bash
# Send 10 requests rapidly
for i in {1..10}; do
  curl ${API_URL}/health
done
```
- [ ] All requests return 200
- [ ] No timeout errors
- [ ] Average response time < 1 second

### Jenkins + AWS Integration (Optional)
1. Update `ci/Jenkinsfile`:
   - Uncomment AWS deployment stages
   - Set ECR_REGISTRY environment variable
2. Configure IAM role on Jenkins EC2 instance
3. Trigger pipeline from Jenkins

- [ ] Jenkins can authenticate to ECR
- [ ] Pipeline pushes image to ECR
- [ ] SAM deployment triggered from Jenkins
- [ ] API Gateway updated with new deployment

### Cleanup
```bash
# Delete SAM stack
sam delete

# Delete ECR repository
aws ecr delete-repository \
  --repository-name aws-lab-flask-demo \
  --force \
  --region us-east-1
```
- [ ] CloudFormation stack deleted
- [ ] Lambda function removed
- [ ] API Gateway removed
- [ ] ECR repository deleted
- [ ] No lingering resources

**Phase 4 Checkpoint**: End-to-end deployment successful, API accessible via API Gateway, logs visible in CloudWatch

---

## Final Validation

### Code Quality
- [ ] All Python files follow PEP 8
- [ ] No linting errors
- [ ] Functions have docstrings
- [ ] Error handling implemented

### Documentation
- [ ] README.md comprehensive and accurate
- [ ] CLAUDE.md helpful for future developers
- [ ] All commands in docs are correct
- [ ] Architecture clearly explained

### Testing
- [ ] Unit test coverage for /health endpoint
- [ ] Integration test coverage for /echo endpoint
- [ ] Error case testing (invalid JSON, wrong methods)
- [ ] All tests pass locally

### CI/CD
- [ ] Jenkinsfile syntax correct
- [ ] All pipeline stages defined
- [ ] AWS stages commented out for local use
- [ ] Fail-fast on test failures

### Infrastructure
- [ ] SAM template valid
- [ ] Lambda function configurable
- [ ] API Gateway properly configured
- [ ] CloudWatch logging enabled

### Git Repository
- [ ] All files committed
- [ ] .gitignore excludes unnecessary files
- [ ] Commit messages descriptive
- [ ] Branch organization clear

---

## Success Criteria Summary

✅ **SC-001**: Clone to working `/health` in < 15 minutes
✅ **SC-002**: Docker build + run in < 3 minutes
✅ **SC-003**: Jenkins pipeline complete in < 10 minutes
✅ **SC-004**: API Gateway `/health` returns 200 (3x consecutive)
✅ **SC-005**: CloudWatch shows recent logs from both endpoints

---

## Troubleshooting Reference

### Issue: Tests fail locally
```bash
cd backend
. .venv/bin/activate  # or conda activate aws-lab-flask
pytest tests/ -v
```
Check error messages and verify Flask app syntax

### Issue: Docker build fails
```bash
docker build --no-cache -t aws-lab-flask-demo:local backend/
```
Check Dockerfile syntax and .dockerignore

### Issue: Container won't start
```bash
docker logs <container-id>
```
Look for Python errors or missing dependencies

### Issue: Jenkins pipeline fails
- Check Jenkins console output for specific stage
- Verify Docker socket access
- Ensure Python 3 available on Jenkins agent

### Issue: SAM deploy fails
```bash
sam validate  # Check template syntax
aws sts get-caller-identity  # Verify credentials
```

### Issue: API Gateway returns errors
- Check Lambda function logs in CloudWatch
- Verify container image is in ECR
- Check IAM permissions

---

## Validation Complete

Once all checkboxes are marked, the AWS Flask CI/CD project is fully validated and ready for demonstration or production use.
