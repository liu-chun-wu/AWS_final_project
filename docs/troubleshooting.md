# Troubleshooting Cheatsheet

## Local Environment

- **Python module errors** – Recreate the virtualenv (`python3.11 -m venv .venv && source .venv/bin/activate`) and reinstall dependencies (`pip install -r requirements.txt`).
- **Docker build failures** – Run `./scripts/local/build-local.sh --demo` with `set -x` enabled inside the script to surface the failing layer, then rebuild.
- **Tests fail intermittently** – Use `pytest -k <name> -vv --maxfail=1` to isolate the flaky test before retrying Jenkins.

## Jenkins (Local or EC2)

- **Pipeline stuck at “Checkout”** – Verify the Jenkins instance can reach GitHub (corporate proxies/VPN). Reconfigure SSH keys or HTTPS credentials if prompted.
- **Docker permission issues** – Ensure the Jenkins user belongs to the `docker` group (handled by our setup scripts). Restart Jenkins after modifying group membership.
- **Credential errors calling AWS** – For local Jenkins, refresh the AWS profile mapped into the container. For EC2 Jenkins, run `aws sts get-caller-identity` on the host to confirm the LabRole is active.
- **Webhook delivers but job not triggered** – Confirm the GitHub webhook URL matches the current EC2 public IP and that port 8080 is open in the security group.

## AWS Deployment

- **SAM fails due to IAM role creation** – Double-check `aws/template.yaml` references `LabRole`; Learner Lab cannot create new IAM roles.
- **Missing ECR image** – Run `./scripts/jenkins/20-ci-build-and-push.sh --demo` (or trigger `flask-ci`) to push the latest image, then redeploy.
- **API returns 500** – Inspect CloudWatch logs with `sam logs -n DemoFunction --stack-name flask-demo-backend --region us-east-1`. Most issues relate to mismatched environment variables or payload validation.
- **Old stack artifacts** – Remove stacks with `sam delete --config-file aws/samconfig-demo.toml` (demo) or the prod equivalent, and manually delete unused ECR images.

If you hit something outside these scenarios, reproduce it with the manual scripts first; that narrows the blast radius before involving Jenkins or AWS support.
