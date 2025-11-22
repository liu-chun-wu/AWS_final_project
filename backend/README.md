# Production Backend

This directory is for the actual production service implementation.

## For Collaborators

This is where you implement the real production service. The `demo-backend/` directory contains a simple Flask demo used for CI/CD validation and should not be modified.

### Directory Structure

```
backend/
├── src/                    # Your application code goes here
├── tests/
│   ├── unit/              # Unit tests for your code
│   └── integration/       # Integration tests
├── requirements.txt       # Python dependencies
├── Dockerfile            # Container configuration
└── README.md            # This file
```

### Getting Started

1. **Install dependencies:**
   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Add your dependencies:**
   ```bash
   pip install <your-package>
   pip freeze > requirements.txt
   ```

3. **Implement your service in `src/`:**
   - Create your application entry point (e.g., `src/app.py`)
   - Add your business logic
   - Ensure it's containerizable

4. **Write tests:**
   - Unit tests in `tests/unit/`
   - Integration tests in `tests/integration/`
   - All tests must pass for CI/CD to succeed

## Testing Locally

### Run tests only:
```bash
./scripts/local/test-local.sh
```

### Build Docker image locally:
```bash
./scripts/local/build-local.sh
```

### Run containerized app:
```bash
docker run --rm -p 8000:8000 aws-lab-flask-demo:local
```

## CI/CD Workflow

### Development (Jeffery Branch)
Push to Jeffery branch runs **CI only** (no AWS deployment):
- Checkout code
- Setup Python environment
- Install dependencies
- Run tests
- Build Docker image

```bash
git checkout Jeffery
# ... make changes ...
git add .
git commit -m "feat: your feature"
git push origin Jeffery
```

Jenkins will test and build but NOT deploy to AWS.

### Production (Main Branch)
Push to main branch runs **full CI/CD** (deploys to AWS):
- All CI stages (above)
- Login to AWS ECR
- Push Docker image to ECR
- Deploy to AWS Lambda via SAM

```bash
git checkout main
git merge Jeffery
git push origin main
```

Jenkins will test, build, AND deploy to AWS.

## Important Notes

1. **Python Version:** Must use Python 3.11 (AWS Lambda compatibility)

2. **Tests Must Pass:** Pipeline fails if tests fail (fail-fast principle)

3. **Dockerfile:** Must be Lambda-compatible if deploying to AWS

4. **Port:** Application should listen on port 8000

5. **Stateless Design:** No local database or sessions (serverless best practice)

## Deployment Configuration

This backend uses the **production** SAM configuration:
- Config file: `aws/samconfig-prod.toml`
- Stack name: `flask-prod-backend`
- Separate from demo deployment

## Need Help?

- **Branch Strategy:** See `BRANCH_STRATEGY.md`
- **Collaboration Guide:** See `COLLABORATION.md`
- **AWS Deployment:** See `AWS_DEPLOYMENT_GUIDE.md`
- **Troubleshooting:** See `TROUBLESHOOTING.md`
- **Scripts Documentation:** See `scripts/README.md`

## Demo Backend

For CI/CD validation reference, see `demo-backend/` which contains:
- Simple Flask app with /health and /echo endpoints
- 18 passing tests
- Working CI/CD pipeline configuration
- Use as a template if needed
