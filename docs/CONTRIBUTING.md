# Contributing Guide

How to contribute to this project effectively.

## Table of Contents

- [Development Workflow](#development-workflow)
- [Code Style](#code-style)
- [Testing Requirements](#testing-requirements)
- [Git Workflow](#git-workflow)
- [Documentation Standards](#documentation-standards)
- [Security Guidelines](#security-guidelines)

---

## Development Workflow

### Getting Started

```bash
# 1. Clone and checkout development branch
git clone <repository-url>
cd AWS_final_project
git checkout Jeffery

# 2. Setup Python environment
cd backend
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 3. Verify setup
cd ..
./scripts/local/test-local.sh --prod
```

### Daily Development

```bash
# 1. Pull latest changes
git checkout Jeffery
git pull origin Jeffery

# 2. Make changes in backend/src/

# 3. Write tests in backend/tests/

# 4. Run tests locally
./scripts/local/test-local.sh --prod

# 5. Commit and push
git add backend/
git commit -m "feat: your feature description"
git push origin Jeffery
```

### What to Modify

| Directory | Modify? | Description |
|-----------|---------|-------------|
| `backend/src/` | Yes | Production application code |
| `backend/tests/` | Yes | Test files |
| `backend/requirements.txt` | Yes | Python dependencies |
| `demo-backend/` | No | CI/CD validation baseline |
| `jenkins-pipeline-setting/` | Ask first | Pipeline definitions |
| `scripts/` | Ask first | Automation scripts |

---

## Code Style

### Python Standards

- **PEP 8** compliance
- **4-space** indentation
- **snake_case** for functions and variables
- **PascalCase** for classes
- **UPPER_CASE** for constants

### Function Guidelines

```python
def get_user_history(user_id: str) -> dict:
    """
    Retrieve generation history for a user.

    Args:
        user_id: The user identifier

    Returns:
        Dictionary with success status and records list
    """
    # Implementation
```

### Logging

Use structured logging similar to the existing patterns:

```python
import logging
logger = logging.getLogger(__name__)

logger.info(f"Processing request for user: {user_id}")
logger.error(f"API call failed: {error}")
```

### Dependencies

- Pin exact versions in `requirements.txt`
- Add only necessary dependencies
- Test locally after adding new packages

```bash
pip install new-package
pip freeze > requirements.txt
```

---

## Testing Requirements

### Test Structure

```
backend/tests/
├── unit/               # Unit tests (fast, isolated)
│   ├── test_health.py
│   └── test_feature.py
└── integration/        # Integration tests (full flow)
    └── test_api.py
```

### Writing Tests

**Unit test example:**
```python
def test_health_returns_200():
    from src.app import create_app
    app = create_app()
    with app.test_client() as client:
        response = client.get('/health')
        assert response.status_code == 200
```

**Integration test example:**
```python
def test_generate_image_requires_prompt():
    from src.app import create_app
    app = create_app()
    with app.test_client() as client:
        response = client.post('/generate-image',
                              json={},
                              content_type='application/json')
        assert response.status_code == 400
```

### Test Requirements

- All tests must pass before pushing
- New features require test coverage
- Keep tests fast (< 1 second per test)
- Use descriptive test names
- Mock external API calls

### Running Tests

```bash
# All tests
./scripts/local/test-local.sh --prod

# Specific file
cd backend
pytest tests/unit/test_feature.py -v

# Specific test
pytest tests/unit/test_feature.py::test_specific -v
```

---

## Git Workflow

### Branch Strategy

- **Jeffery** - Development branch (CI auto-triggered)
- **main** - Production branch (team lead merges)

### Commit Messages

Follow conventional commit format:

```
feat: add user authentication endpoint
fix: handle empty prompt in generate-image
test: add integration tests for history endpoint
docs: update API documentation
refactor: simplify database helper functions
```

**Guidelines:**
- Subject line ≤ 72 characters
- Use present tense ("add" not "added")
- Be specific about what changed

### Pull Request Process

1. Ensure Jeffery CI is green
2. Create PR with description:
   - What changed and why
   - Link to related issue
   - Test results or Jenkins URL
3. Request review from team lead
4. Address feedback
5. Team lead merges after approval

---

## Documentation Standards

### When to Update Docs

- New features or endpoints
- Changed behavior
- New environment variables
- Breaking changes

### Documentation Locations

| Type | Location |
|------|----------|
| Application docs | `docs/APPLICATION.md` |
| CI/CD docs | `docs/CI_CD.md` |
| API reference | `backend/README.md` |
| Scripts | `docs/SCRIPTS.md` |

### Markdown Format

- Use H2 (`##`) for major sections
- Use code blocks with language tags
- Keep lines reasonable length
- Use tables for structured data
- Include examples

---

## Security Guidelines

### Never Commit

- AWS credentials
- API tokens
- Passwords
- Private keys
- `.env` files

### Environment Variables

Store sensitive values in environment:

```bash
# backend/.env (DO NOT COMMIT)
AWS_ACCESS_KEY_ID=...
HUGGINGFACE_TOKEN=...
```

### AWS Credentials

```bash
# Use AWS CLI configuration
aws configure

# Or environment variables
export AWS_ACCESS_KEY_ID=...
```

### Learner Lab Credentials

- Credentials expire every 3-4 hours
- Refresh from AWS Learner Lab dashboard
- Update local `.env` file
- Recreate Docker containers after update

---

## Quick Reference

### Common Commands

```bash
# Test locally
./scripts/local/test-local.sh --prod

# Build Docker
./scripts/local/build-local.sh --prod

# Run container
docker run --rm -p 8000:8000 --env-file backend/.env aws-lab-flask-demo:local

# Check endpoint
curl http://localhost:8000/health
```

### Getting Help

- Check existing documentation
- Review similar code in `demo-backend/`
- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Ask team lead

---

## See Also

- [Quick Start](QUICK_START.md)
- [Application Documentation](APPLICATION.md)
- [CI/CD Pipeline](CI_CD.md)
- [Testing Guide](TESTING.md)
