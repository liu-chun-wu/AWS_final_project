# AWS Learner Lab Flask CI/CD Demo

A comprehensive demonstration project showcasing a complete CI/CD pipeline from local Flask development to AWS Lambda deployment. This project implements a simple REST API with automated testing, containerization, and cloud deployment.

## Project Overview

This project demonstrates:
- **Local Development**: Flask REST API with health check and echo endpoints
- **Containerization**: Docker packaging for consistent deployment
- **Local CI/CD**: Jenkins pipeline for automated testing and building
- **AWS Integration**: ECR, Lambda containers, API Gateway, and CloudWatch

## Architecture

The project follows a progressive 4-phase design:

1. **Phase 1 - Local Flask**: Stateless REST API running on Python
2. **Phase 2 - Containerization**: Same app packaged in Docker
3. **Phase 3 - Local Jenkins CI**: Automated pipeline with testing and image building
4. **Phase 4 - AWS Deployment**: Production deployment on AWS Lambda with API Gateway

## Prerequisites

- **Python 3.11** (required for AWS Lambda compatibility)
- **Conda** or **virtualenv** for environment management
- **Docker** for containerization
- **Git** for version control
- **AWS Account** (AWS Learner Lab for Phase 4)
- **AWS CLI** (for AWS deployment)
- **AWS SAM CLI** (for infrastructure deployment)

## Project Structure

```
aws-lab-flask-ci-cd/
├── backend/
│   ├── src/
│   │   ├── __init__.py
│   │   └── app.py              # Flask application
│   ├── tests/
│   │   ├── unit/               # Unit tests
│   │   └── integration/        # Integration tests
│   ├── requirements.txt        # Python dependencies
│   ├── Dockerfile              # Container definition
│   └── .dockerignore
├── ci/
│   └── Jenkinsfile             # CI/CD pipeline
├── aws/
│   └── template.yaml           # SAM template
├── specs/                      # Planning documentation
├── .gitignore
├── CLAUDE.md                   # Developer guide for Claude Code
└── README.md
```

## Quick Start

### 1. Local Development

#### Setup Python Environment

**Using Conda (Recommended):**
```bash
# Create and activate environment
conda create -n aws-lab-flask python=3.11 -y
conda activate aws-lab-flask

# Install dependencies
cd backend
pip install -r requirements.txt
```

**Using virtualenv (Alternative):**
```bash
# Create virtual environment
python3.11 -m venv .venv

# Activate environment
source .venv/bin/activate  # macOS/Linux
# OR
.venv\Scripts\activate     # Windows

# Install dependencies
cd backend
pip install -r requirements.txt
```

#### Run Application Locally

```bash
# Method 1: Using Flask CLI
export FLASK_APP=src.app
flask run --port 8000

# Method 2: Direct Python execution
python src/app.py
```

#### Test Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Expected response: {"status": "ok", "service": "demo-backend"}

# Echo endpoint
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "hello world", "count": 42}'

# Expected response: {"body": {"message": "hello world", "count": 42}}
```

#### Run Tests

```bash
# Run all tests
pytest tests/

# Run only unit tests
pytest tests/unit/

# Run only integration tests
pytest tests/integration/

# Run with verbose output
pytest tests/ -v
```

---

### 2. Docker Usage

#### Build Docker Image

```bash
docker build -t aws-lab-flask-demo:local backend/
```

#### Run Container

```bash
docker run --rm -p 8000:8000 aws-lab-flask-demo:local
```

#### Test Containerized Application

```bash
# Health check
curl http://localhost:8000/health

# Echo endpoint
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### View Container Logs

```bash
# Get container ID
docker ps

# View logs
docker logs <container-id>

# Follow logs
docker logs -f <container-id>
```

---

### 3. Jenkins CI Pipeline

#### Setup Jenkins Locally

```bash
# Start Jenkins in Docker with Docker socket access
docker run -d \
  --name jenkins-local \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

# Get initial admin password
docker exec jenkins-local cat /var/jenkins_home/secrets/initialAdminPassword
```

#### Configure Jenkins

1. Access Jenkins at http://localhost:8080
2. Enter the initial admin password
3. Install suggested plugins + **Docker Pipeline** plugin
4. Create a new Pipeline job
5. Configure SCM:
   - Repository URL: Your Git repository
   - Branch: `main` or `Jeffery`
6. Set Pipeline script path: `ci/Jenkinsfile`
7. Save and trigger a build

#### Validate Pipeline

- **Success case**: Trigger build manually → all stages should complete successfully
- **Failure case**: Intentionally break a test → pipeline should fail at the test stage
- **Performance**: Total pipeline execution should complete in < 10 minutes

---

### 4. AWS Deployment

#### Prerequisites

- AWS Learner Lab account active
- AWS CLI configured with credentials
- AWS SAM CLI installed
- Region: `us-east-1`

#### Create ECR Repository

```bash
# Create repository
aws ecr create-repository \
  --repository-name aws-lab-flask-demo \
  --region us-east-1

# Note the repository URI (example):
# 123456789012.dkr.ecr.us-east-1.amazonaws.com/aws-lab-flask-demo
```

#### Manual Deployment Test

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ecr-uri>

# Tag and push image
docker tag aws-lab-flask-demo:local <ecr-uri>:latest
docker push <ecr-uri>:latest

# Deploy with SAM
cd aws
sam build
sam deploy --guided
```

#### Test Deployed API

```bash
# Get API Gateway URL from SAM output
# Test health endpoint
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/health

# Test echo endpoint
curl -X POST https://<api-id>.execute-api.us-east-1.amazonaws.com/Prod/echo \
  -H "Content-Type: application/json" \
  -d '{"test": "aws deployment"}'
```

#### View CloudWatch Logs

```bash
# List log groups
aws logs describe-log-groups --region us-east-1

# Tail logs (replace with your function name)
aws logs tail /aws/lambda/<function-name> --follow
```

#### Cleanup AWS Resources

```bash
# Delete SAM stack
sam delete

# Delete ECR repository
aws ecr delete-repository \
  --repository-name aws-lab-flask-demo \
  --force \
  --region us-east-1
```

---

## API Endpoints

### GET /health

Health check endpoint for monitoring and container orchestration.

**Request:**
```bash
curl http://localhost:8000/health
```

**Response:**
```json
{
  "status": "ok",
  "service": "demo-backend"
}
```

**Status Code:** 200 OK

---

### POST /echo

Echo endpoint that returns the request body for testing purposes.

**Request:**
```bash
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"message": "hello", "data": {"nested": "value"}}'
```

**Response:**
```json
{
  "body": {
    "message": "hello",
    "data": {
      "nested": "value"
    }
  }
}
```

**Status Code:** 200 OK

**Error Cases:**
- Missing `Content-Type: application/json` → 400 Bad Request
- Invalid JSON payload → 400 Bad Request
- Empty request body → 400 Bad Request

---

## Development Workflow

### Making Changes

1. Create a feature branch
2. Make code changes
3. Write/update tests
4. Run tests locally: `pytest tests/`
5. Test in Docker: `docker build && docker run`
6. Commit changes with descriptive message
7. Push to repository
8. Jenkins pipeline runs automatically (if configured)
9. Review build results

### Testing Strategy

- **Unit Tests**: Test individual endpoints in isolation using Flask test client
- **Integration Tests**: Test full request/response cycle
- **Container Tests**: Verify behavior is identical in Docker
- **CI Validation**: Ensure pipeline fails when tests fail

---

## Troubleshooting

### Python Environment Issues

```bash
# Verify Python version
python --version  # Should be 3.11.x

# Recreate environment
conda env remove -n aws-lab-flask
conda create -n aws-lab-flask python=3.11 -y
conda activate aws-lab-flask
pip install -r backend/requirements.txt
```

### Docker Build Failures

```bash
# Check Docker is running
docker ps

# Clear Docker cache
docker system prune -a

# Rebuild without cache
docker build --no-cache -t aws-lab-flask-demo:local backend/
```

### Port Already in Use

```bash
# Find process using port 8000
lsof -i :8000

# Kill process (replace PID)
kill -9 <PID>

# Or use different port
flask run --port 8001
```

### AWS Credential Issues

```bash
# Verify AWS credentials
aws sts get-caller-identity

# For Learner Lab: refresh credentials from lab page
# Copy and paste new credentials to ~/.aws/credentials
```

---

## Technology Stack

- **Python 3.11** - Required for AWS Lambda compatibility
- **Flask 3.0** - Web framework
- **Gunicorn 21.2** - WSGI server for production
- **Pytest 7.4** - Testing framework
- **Docker** - Containerization
- **Jenkins** - CI/CD automation
- **AWS ECR** - Container registry
- **AWS Lambda** - Serverless compute (container mode)
- **AWS API Gateway** - HTTP API frontend
- **AWS CloudWatch** - Logging and monitoring
- **AWS SAM** - Infrastructure as Code

---

## Learning Objectives

This project demonstrates:

1. **Flask application development** with RESTful API design
2. **Test-Driven Development** (TDD) with pytest
3. **Docker containerization** for consistent environments
4. **CI/CD pipeline** implementation with Jenkins
5. **AWS serverless deployment** with Lambda containers
6. **Infrastructure as Code** with AWS SAM
7. **Cloud-native logging** with CloudWatch
8. **DevOps best practices** and automation

---

## License

This is an educational project for AWS Learner Lab demonstration purposes.

---

## Additional Resources

- [Flask Documentation](https://flask.palletsprojects.com/)
- [Docker Documentation](https://docs.docker.com/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [AWS Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)

---

## Project Status

- [x] Planning and documentation
- [x] Phase 1: Local Flask implementation
- [x] Phase 2: Docker containerization
- [x] Phase 3: Jenkins CI pipeline
- [x] Phase 4: AWS deployment (infrastructure ready, requires manual deployment)
