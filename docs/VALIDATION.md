# Validation Checklist

Use this quick list to confirm the pipeline still works after significant changes.

## 1. Local Service
- `./scripts/local/test-local.sh --demo` passes (unit + integration tests).
- `./scripts/local/build-local.sh --demo` builds the Docker image without errors.
- `curl http://localhost:8000/health` returns `{"status":"ok"}` when running the local server.

## 2. Manual CI/CD Scripts
- `./scripts/jenkins/20-ci-build-and-push.sh --demo` completes and pushes a tagged image to ECR.
- `./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag <tag>` deploys successfully.
- `./scripts/jenkins/32-cd-verify-deployment.sh --demo` confirms `/health` and `/echo` behave as expected.

## 3. Local Jenkins
- `flask-ci` (pointing to `jenkins-pipeline-setting/Jenkinsfile-CI`) runs green inside the Dockerized Jenkins controller.
- `flask-cd` can deploy the same tag manually (Build with Parameters → BACKEND_DIR + IMAGE_TAG, or leave IMAGE_TAG blank to auto-detect).

## 4. EC2 Jenkins + Webhook
- `./scripts/jenkins/41-setup-jenkins-ec2.sh --demo` (only when recreating; defaults t3.medium) followed by `./scripts/jenkins/42-configure-jenkins-jobs.sh --ec2 --demo` leaves both jobs configured.
- A push to `Jeffery` triggers the CI job; run `flask-cd` manually when you are ready to deploy the approved image tag.
- Post-deployment verification using `./scripts/jenkins/32-cd-verify-deployment.sh --prod` succeeds.

If any step fails, roll back to the previous layer (manual scripts → local Jenkins → EC2 Jenkins) before retrying.
