# Jenkins Playbook

Use this guide to move from manual scripts to Jenkins automation in two predictable steps.

## 1. Local Jenkins (Docker)

1. Run `./scripts/jenkins/40-setup-jenkins-local.sh`.
   - Requires Docker Desktop running.
   - Mounts the repository and Docker socket so container builds work.
2. Visit `http://localhost:8080` and unlock Jenkins using the password printed by the script.
3. Install plugins: Git, GitHub, workflow-aggregator (Pipeline), credentials-binding, docker-workflow + docker-commons, aws-credentials, Blue Ocean. The configure script installs these with retries and pinned versions.
4. Update knobs once in `scripts/jenkins/env-common.sh` (image/ECR name, region, branch allow-list, stack names, SAM configs, GitHub repo, job names); all Jenkins scripts and Jenkinsfiles now read from there. Jenkinsfiles do not rely on top-level environment defaults—values are injected in the “Load Pipeline Config” stage after checkout to avoid stale defaults.
5. (Optional) Run `./scripts/jenkins/42-configure-jenkins-jobs.sh --local --demo` to auto-create the `flask-ci` and `flask-cd` jobs. Otherwise create them manually:
   - `flask-ci` → points to `jenkins-pipeline-setting/Jenkinsfile-CI`.
   - `flask-cd` → points to `jenkins-pipeline-setting/Jenkinsfile-CD`.
6. Add AWS credentials (access key/secret + session token) via Credentials → Secret text / AWS creds. Jenkinsfiles bind `aws-lab-creds` and `aws-session-token`, and they self-install AWS/SAM CLI if missing.
7. Trigger both jobs manually; confirm they pass just like the manual scripts.

> Run local Jenkins whenever you need the friendly UI or want to dry-run Jenkinsfile edits without touching AWS infrastructure.

## 2. Jenkins on EC2

1. Provision the instance (defaults to `t3.medium`, override with `INSTANCE_TYPE=` if needed):
   ```bash
   ./scripts/jenkins/41-setup-jenkins-ec2.sh
   ```
   - Launches a t3.medium in us-east-1, attaches LabRole, installs Docker + Jenkins + SAM.
   - Prints the public URL and admin password.
2. Configure jobs automatically:
   ```bash
   ./scripts/jenkins/42-configure-jenkins-jobs.sh --ec2 --demo
   ```
   - Creates `flask-ci` and `flask-cd`, both “Pipeline from SCM” jobs reading Jenkinsfiles from `jenkins-pipeline-setting/`.
3. Update the GitHub webhook to point at `http://<ec2-ip>:8080/github-webhook/` (this triggers the CI job only; run `flask-cd` manually when you want to deploy) and resend a test payload.
4. Use the start/stop scripts to control cost:
   ```bash
   ./scripts/jenkins/93-start-jenkins-ec2.sh
   ./scripts/jenkins/94-stop-jenkins-ec2.sh
   ```
5. After each restart, recheck the webhook IP and rerun a quick build to ensure credentials are valid.

## Operational Tips

- Keep EC2 Jenkins stopped outside work hours; EBS storage is the only cost while stopped.
- Always push Jenkinsfile fixes to Git before running `42-configure-jenkins-jobs.sh`; the script only reads from the repository.
- Use `scripts/jenkins/91-check-jenkins-status.sh` to grab logs and Blue Ocean URLs when something looks off.
- When experimenting, use the `demo-backend` parameter so you don’t impact the production stack.
