# Repository Guidelines

## Project Structure & Module Organization
Primary work happens in `backend/`: application code stays in `src/`, while `tests/unit` and `tests/integration` mirror the same module layout for parity. `demo-backend/` is the locked benchmark app that Jenkins uses to prove the pipeline; use it only for reference. CI/CD definitions hang under `ci/`, local helpers live in `scripts/local/`, and shared Jenkins automation plus EC2 tooling lives in `scripts/jenkins/`. Infrastructure specs live in `aws/`, and their rationale is captured in `docs/` and `specs/`.

## Build, Test, and Development Commands
- `python3.11 -m venv .venv && source .venv/bin/activate` in `backend/` to match the Lambda runtime before installing requirements.
- `./scripts/local/test-local.sh --prod` (or `--demo`) runs the same pytest suite that Jenkins executes in Stage 5.
- `./scripts/local/build-local.sh --prod` reproduces the container build that later pushes to ECR.
- AWS pipeline dry-runs use `./scripts/jenkins/20-ci-build-and-push.sh` and `31-cd-deploy-sam.sh`; stop after the CI script unless you intend to touch real AWS resources. Deployments from Jenkins are triggered manually via the `flask-cd` job (choose BACKEND_DIR + IMAGE_TAG).

## Coding Style & Naming Conventions
Treat the codebase as a PEP 8 project: four-space indents, snake_case for functions/modules, PascalCase for classes, and descriptive constants (e.g., `MAX_PAYLOAD_BYTES`). Add docstrings and structured logging similar to `demo-backend/src/app.py`, and pin versions in `requirements.txt`. Keep secrets, AWS ARNs, and account IDs out of source; surface them through environment variables or SAM parameters.

## Testing Guidelines
Every new handler or service must ship with pytest coverage in `backend/tests`, respecting the existing unit/integration split and `test_<behavior>.py` naming. Keep suites deterministic by mocking external calls. Reproduce failures locally with `pytest tests/ -v --tb=short` (invoked by the test script) before pushing, and block merges unless the Jeffery-branch pipeline is green.

## Commit & Pull Request Guidelines
Follow the existing conventional style shown in `git log` (`feat: Enhance AWS scripts...`, `test local CI`). Keep subject lines ≤72 chars, avoid stacking “WIP” commits on Jeffery, and squash noisy fixups. Pull requests must describe scope, link the tracking issue, attach output from `./scripts/local/test-local.sh --prod` or a Jenkins URL, and explain any AWS impact (e.g., Lambda alias updates). Request review only after the Jeffery branch pipeline succeeds.

## Security & Configuration Tips
Store AWS credentials locally via `aws configure` and rely on the provided `samconfig*.toml` files for profile/region wiring instead of committing secrets. Use `scripts/jenkins/93-start-jenkins-ec2.sh` and `94-stop-jenkins-ec2.sh` to control the Jenkins EC2 budget, and rotate any tokens when prompted. Remove local `.venv`, `.pytest_cache`, and build artifacts before committing so the repo stays lean.
