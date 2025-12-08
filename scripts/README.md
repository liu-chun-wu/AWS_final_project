# Automation Scripts

The automation toolkit is split into two folders so you can tell whether a command is safe for local smoke testing or intended for Jenkins automation.

## scripts/local/

| Script | Description | Typical Use |
|--------|-------------|-------------|
| `test-local.sh --demo|--prod` | Runs the pytest suite for the selected backend. | Run before every commit and whenever Jenkins reports a failing test. |
| `build-local.sh --demo|--prod` | Builds the Docker image tagged `:local` for smoke testing. | Validate Dockerfile edits without touching AWS/ECR. |

These scripts never talk to AWS; they live entirely on your workstation.

## scripts/jenkins/

| Script | Description |
|--------|-------------|
| `40-setup-jenkins-local.sh` | Boots Jenkins LTS in Docker with the repo + Docker socket mounted so you can dry-run Jenkinsfiles locally. |
| `11-setup-ecr.sh` | Creates (or confirms) the Amazon ECR repository used by both demo and production deployments. |
| `20-ci-build-and-push.sh` | Runs tests, builds the container, logs into ECR, and pushes the image. Mirrors Jenkins CI. |
| `30-cd-validate-sam.sh` | Runs SAM validation, checks LabRole, and ensures the template is ready to deploy. |
| `31-cd-deploy-sam.sh` | Deploys the specified image tag to Lambda/API Gateway via SAM (`--demo` or `--prod`). |
| `32-cd-verify-deployment.sh` | Calls `/health` and `/echo` on the deployed API for quick verification. |
| `41-setup-jenkins-ec2.sh` | Provisions Jenkins on EC2 (default t3.medium), installs dependencies, and prints the admin password. |
| `42-configure-jenkins-jobs.sh` | Uses Jenkins CLI/API to create `flask-ci` and `flask-cd` jobs pointing to the Jenkinsfiles in Git (`--local` or `--ec2`). |
| `91-check-jenkins-status.sh` | Shows EC2 Jenkins status, Blue Ocean URLs, and recent builds. |
| `93-start-jenkins-ec2.sh` / `94-stop-jenkins-ec2.sh` | Start or stop the EC2 instance to control cost; update the GitHub webhook after a restart. |

Every Jenkinsfile stage shells out to these scripts, so fixes here benefit manual runs, local Jenkins, and EC2 Jenkins simultaneously. For detailed usage examples, see `docs/scripts.md`.
