# Script Catalog

The repository exposes two script groups so you always know whether you are running a manual helper or an automation step that Jenkins can reuse.

## Local Helpers (`scripts/local/`)

| Script | Purpose | Typical Use |
|--------|---------|-------------|
| `test-local.sh --demo|--prod` | Run the full pytest suite for the selected backend. | Run before every commit or when debugging failing tests. |
| `build-local.sh --demo|--prod` | Build the Docker image tagged as `:local` for smoke testing. | Validate Dockerfile changes without touching ECR. |

> These scripts never touch AWS resources. They help you reproduce issues quickly from a terminal.

## Jenkins Toolkit (`scripts/jenkins/`)

| Script | Role | Notes |
|--------|------|-------|
| `40-setup-jenkins-local.sh` | Boot Jenkins LTS in Docker with Docker socket + repo mounted. | Use once per machine or when recreating the local controller. |
| `11-setup-ecr.sh` | Create (or confirm) the ECR repository. | Idempotent; safe to rerun. |
| `20-ci-build-and-push.sh` | Run tests, build the container, and push to ECR. | Mirrors Jenkins CI stage. |
| `30-cd-validate-sam.sh` | Validate template, LabRole, and SAM build. | Ensures SAM deploy will succeed. |
| `31-cd-deploy-sam.sh` | Deploy image to Lambda/API Gateway via SAM. | Accepts `--demo` or `--prod` and an image tag. |
| `32-cd-verify-deployment.sh` | Hit `/health` and `/echo` after deployment. | Use for smoke tests or post-release checks. |
| `41-setup-jenkins-ec2.sh` | Provision Jenkins on EC2 (Amazon Linux 2023). | Defaults to `t3.medium`; creates SG, installs Jenkins, prints URL/password. |
| `42-configure-jenkins-jobs.sh` | Configure `flask-ci` and `flask-cd` jobs via CLI/API. | Uses Jenkinsfiles in `jenkins-pipeline-setting/`; handles plugin install with retries. |
| `91-check-jenkins-status.sh` | Show EC2 Jenkins health/URL/logs. | Requires SSH access to the instance. |
| `93-start-jenkins-ec2.sh` / `94-stop-jenkins-ec2.sh` | Start/stop the EC2 instance to manage cost. | Update GitHub webhook IP after a restart. |
| `99-cleanup-all.sh` | Delete demo/prod stacks and ECR repo. | Use with care; prompts for confirmation. |

Every Jenkinsfile stage calls into these scripts, so improving one script automatically benefits manual runs, local Jenkins, and EC2 Jenkins. The Jenkinsfiles live in `jenkins-pipeline-setting/` and are the single source of truth for both CI and CD.
