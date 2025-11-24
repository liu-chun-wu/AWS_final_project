# AWS Learner Lab Flask CI/CD Demo – Development Guidelines

Auto-generated from feature spec and plan. Last updated: 2025-11-21

## Active Technologies

- Python 3.11
- Flask 3.x
- Gunicorn (for container entrypoint)
- Docker / Docker Compose (local)
- Jenkins (Pipeline-as-code)
- Git / GitHub
- AWS CLI & AWS SAM CLI
- AWS Lambda (container images)
- Amazon API Gateway (HTTP API or REST API)
- Amazon ECR (Elastic Container Registry)
- AWS CloudWatch (Logs, metrics, alarms)
- AWS EC2 (for Jenkins host inside Learner Lab)
- AWS IAM (roles and permissions for CI/CD & Lambda)

## Project Structure

```text
aws-lab-flask-ci-cd/
├── backend/
│   ├── src/
│   │   └── app.py              # Flask application entrypoint
│   ├── tests/
│   │   ├── unit/
│   │   │   └── test_health.py
│   │   └── integration/
│   │       └── test_echo.py
│   ├── requirements.txt
│   └── Dockerfile              # Container image for Lambda & local runs
├── ci/
│   └── Jenkinsfile             # Jenkins Pipeline definition
└── README.md
```

### Local Python development (with Conda)

We recommend using **Conda** for local development. The Docker image and AWS Lambda deployment will still use `pip` with `requirements.txt`, so everything stays compatible.

```bash
# 1. Create Conda environment (only once)
conda create -n aws-lab-flask python=3.11 -y

# 2. Activate environment
conda activate aws-lab-flask

# 3. Install Python dependencies into this Conda env
cd backend
pip install -r requirements.txt

# 4. Run Flask app
export FLASK_APP=src.app
flask run --port 8000
```
