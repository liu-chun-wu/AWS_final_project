# Automation Scripts

Scripts for local testing and CI/CD automation.

## Organization

| Folder | Purpose | AWS Access |
|--------|---------|------------|
| `scripts/local/` | Local testing (never touches AWS) | No |
| `scripts/jenkins/` | CI/CD automation | Yes |

## Quick Reference

### Local Scripts

```bash
./scripts/local/test-local.sh --prod|--demo   # Run tests
./scripts/local/build-local.sh --prod|--demo  # Build Docker
```

### Jenkins Scripts

```bash
./scripts/jenkins/11-setup-ecr.sh             # Create ECR repo
./scripts/jenkins/20-ci-build-and-push.sh     # Full CI
./scripts/jenkins/31-cd-deploy-sam.sh         # Deploy
./scripts/jenkins/32-cd-verify-deployment.sh  # Verify
```

## Full Documentation

See [docs/SCRIPTS.md](../docs/SCRIPTS.md) for complete reference with:
- All script descriptions
- Usage examples
- Troubleshooting
