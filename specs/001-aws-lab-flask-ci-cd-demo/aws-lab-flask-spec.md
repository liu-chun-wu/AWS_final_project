# Feature Specification: AWS Learner Lab Flask CI/CD Demo

**Feature Branch**: `[001-aws-lab-flask-ci-cd-demo]`  
**Created**: 2025-11-21  
**Status**: Draft  
**Input**: User description: "Build a demo backend in Flask, containerize it, and wire a Jenkins CI pipeline that later extends to AWS Learner Lab (ECR + Lambda container + API Gateway + CloudWatch)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 – Run Flask demo backend locally (Priority: P1)

As a student developer, I can run a small Flask API on my laptop with simple `GET /health` and `POST /echo` endpoints so that I can quickly test backend behavior without any AWS services or databases.

**Why this priority**: This is the smallest slice that proves the backend works and allows iteration on API behavior without cost.

**Independent Test**: Start the app locally and send curl / Postman requests to `/health` and `/echo`. Both should return valid JSON responses and HTTP 200.

**Acceptance Scenarios**:

1. **Given** the developer has Python 3.11 installed, **When** they follow the quickstart instructions to set up a virtualenv and run Flask, **Then** `GET /health` returns `{"status": "ok", "service": "demo-backend"}` with HTTP 200.
2. **Given** the same app is running and receives a `POST /echo` with a JSON body, **When** the payload is valid JSON, **Then** the response body includes the same JSON under `body` and HTTP status 200.

---

### User Story 2 – Run the backend inside a Docker container (Priority: P1)

As a student developer, I can build and run the same Flask API as a Docker container so that my local environment behaves similarly to AWS Lambda container images.

**Why this priority**: Containerization is a prerequisite for reusing the same image in Amazon ECR and Lambda.

**Independent Test**: With only Docker installed (no Python), run a documented `docker build` and `docker run` sequence. Calls to `/health` and `/echo` should behave identically to the local Python run.

**Acceptance Scenarios**:

1. **Given** Docker is installed, **When** the developer runs `docker build -t aws-lab-flask-demo:local .` and starts the container, **Then** `GET /health` returns the expected JSON.
2. **Given** the container is running, **When** a `POST /echo` JSON request is sent, **Then** the response echoes the payload as in User Story 1.

---

### User Story 3 – Local Jenkins CI pipeline (Priority: P2)

As a student developer, I can configure a Jenkins pipeline (using a Jenkinsfile) that checks out code, installs dependencies, runs tests, and builds the Docker image whenever triggered.

**Why this priority**: This simulates the CI portion of the final architecture and trains the team on pipeline-as-code before touching AWS.

**Independent Test**: Starting from an empty Jenkins instance running in Docker, connect it to the Git repository and run the pipeline. The build completes successfully and produces a Docker image.

**Acceptance Scenarios**:

1. **Given** Jenkins is running in Docker and has access to the Git repo, **When** the pipeline is triggered manually, **Then** all stages (Checkout, Install deps, Tests, Build image) pass.
2. **Given** a failing test is introduced, **When** the pipeline is re-run, **Then** the build is marked as failed and the failing stage is visible.

---

### User Story 4 – AWS CI/CD using Jenkins + ECR + Lambda (Priority: P3)

As a student developer, I can later reuse the same Jenkins pipeline on an EC2 instance inside AWS Learner Lab to build, push the Docker image to ECR, and deploy a Lambda container behind API Gateway using AWS SAM.

**Why this priority**: This is the final integration with AWS and demonstrates familiarity with multiple services within Learner Lab restrictions.

**Independent Test**: From Jenkins running on EC2, trigger the pipeline; it should build the image, push to ECR, and run `sam deploy` to update the Lambda function and API Gateway endpoint.

**Acceptance Scenarios**:

1. **Given** an existing ECR repository and Lambda function defined via SAM, **When** Jenkins runs the deploy stage, **Then** a new image tag is pushed and Lambda is updated to use it.
2. **Given** a newly deployed version, **When** the public API Gateway URL is called at `/health`, **Then** it returns the same JSON as local runs with HTTP 200.

---

### Edge Cases

- What happens when request JSON is invalid or missing for `POST /echo`?
- How does the service respond when Docker image build fails (e.g., syntax error in app)?
- How are AWS credentials / IAM role failures surfaced in the Jenkins deploy stage?
- What happens when the Lambda container exceeds the configured timeout or memory?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST expose `GET /health` returning a static JSON payload confirming service status.
- **FR-002**: System MUST expose `POST /echo` that accepts a JSON body and returns that body under a `body` field in the response.
- **FR-003**: System MUST provide a documented way to run the Flask app locally via Python (without Docker).
- **FR-004**: System MUST provide a Dockerfile that builds a runnable image for both local use and AWS Lambda container deployment.
- **FR-005**: System MUST provide a Jenkins pipeline configuration (Jenkinsfile) that can run locally and later on EC2.
- **FR-006**: System MUST be able to push the built Docker image to an Amazon ECR repository (when AWS phase is enabled).
- **FR-007**: System MUST be deployable as an AWS Lambda function fronted by API Gateway using AWS SAM templates.
- **FR-008**: System MUST publish application logs to CloudWatch Logs in the AWS deployment.

### Key Entities *(include if feature involves data)*

- **Backend Service**: Stateless Flask application that implements HTTP endpoints and logging behavior.
- **Container Image**: Docker image that packages the backend service and its dependencies for local and AWS Lambda use.
- **CI Pipeline Run**: Jenkins execution that builds, tests, and packages the backend.
- **AWS Deployment**: Combination of ECR repository, Lambda function, API Gateway endpoint, and CloudWatch logging configuration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new developer can clone the repository and successfully call `/health` within 15 minutes using only the README.
- **SC-002**: Docker image build and local container run complete in under 3 minutes on a typical student laptop.
- **SC-003**: Jenkins pipeline completes successfully (all stages green) in under 10 minutes.
- **SC-004**: The same image built locally is successfully deployed to AWS Lambda via ECR and SAM, with `/health` returning HTTP 200 at least 3 times in a row.
- **SC-005**: At least one CloudWatch Log group contains recent logs from the Lambda container for both `/health` and `/echo` calls.
