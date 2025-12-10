#!/bin/bash

################################################################################
# CI Pipeline Script: Build and Push Docker Image to ECR
################################################################################
#
# Script: 20-ci-build-and-push.sh
# Purpose: Manual CI (Continuous Integration) testing - Build Docker image and push to ECR
# Usage: ./20-ci-build-and-push.sh [--demo|--prod]
#
# What is CI (Continuous Integration)?
# - Automated process that validates code changes
# - Runs tests to catch bugs early
# - Builds artifacts (Docker images in our case)
# - Pushes artifacts to registry for deployment
# - Fails fast if anything goes wrong (tests, build, push)
#
# This script implements the CI pipeline stages:
# 1. Test - Run pytest to validate code works
# 2. Build - Create Docker container image
# 3. Authenticate - Login to AWS ECR
# 4. Tag - Tag image with ECR URI and version tags
# 5. Push - Upload image to ECR for Lambda deployment
# 6. Verify - Confirm image exists in ECR
#
# What you'll learn:
# - CI pipeline stages and why they matter
# - Docker multi-platform builds (--platform linux/amd64 for Lambda)
# - ECR authentication flow (temporary 12-hour tokens)
# - Docker image tagging strategies
# - Layer-based push optimization
# - Fail-fast principles in automation
#
# AWS Services Used:
# - ECR (Elastic Container Registry) - Store Docker images
# - STS (Security Token Service) - Generate ECR login tokens
#
# Prerequisites:
# - ECR repository created (run ./11-setup-ecr.sh first)
# - Docker daemon running locally
# - AWS CLI configured with valid credentials
# - Python environment with pytest installed
#
# Cost:
# - ECR storage: ~$0.10 per GB per month
# - ECR data transfer: Free within region
# - No compute cost (builds run locally)
#
################################################################################

set -e  # Exit immediately if any command fails (fail-fast principle)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

################################################################################
# Parse Command-Line Arguments
################################################################################

BACKEND_TYPE=""
if [ "$1" == "--demo" ]; then
    BACKEND_TYPE="demo-backend"
    BACKEND_DIR="demo-backend"
elif [ "$1" == "--prod" ]; then
    BACKEND_TYPE="prod-backend"
    BACKEND_DIR="backend"
else
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Backend type required                                  ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Usage: $0 [--demo|--prod]"
    echo ""
    echo "Options:"
    echo "  --demo  Build and push demo-backend (Flask validation demo)"
    echo "  --prod  Build and push production backend"
    echo ""
    echo "Examples:"
    echo "  $0 --demo   # Build demo backend"
    echo "  $0 --prod   # Build production backend"
    echo ""
    echo "What this does:"
    echo "  • Runs pytest to validate code"
    echo "  • Builds Docker image"
    echo "  • Pushes to ECR for Lambda deployment"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "${SCRIPT_DIR}/env-common.sh"

AWS_REGION="${PIPELINE_AWS_REGION:-${AWS_REGION:-us-east-1}}"
REPO_NAME="${PIPELINE_ECR_REPO:-aws-final-project-repo}"
IMAGE_TAG="${IMAGE_TAG:-manual-test}"  # Can be overridden via env var

################################################################################
# Helper Functions for Output Formatting
################################################################################

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

print_command() {
    echo -e "${CYAN}  \$ $1${NC}"
}

print_explain() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

################################################################################
# Introduction
################################################################################

show_introduction() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         PHASE 3a: MANUAL CI TESTING                            ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Build Docker image and push to ECR                           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is CI (Continuous Integration)?"

    print_info "CI is the practice of automatically testing and building code:"
    print_info "  • Developers push code changes to Git"
    print_info "  • Automated pipeline runs tests"
    print_info "  • If tests pass, pipeline builds artifact (Docker image)"
    print_info "  • Artifact pushed to registry (ECR) for deployment"
    print_info "  • If anything fails, pipeline stops (fail-fast)"
    echo ""

    print_info "Why CI matters:"
    print_info "  • Catch bugs early (before deployment)"
    print_info "  • Ensure code quality (tests must pass)"
    print_info "  • Automate repetitive tasks (build, tag, push)"
    print_info "  • Consistent builds (same process every time)"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}Backend Type:${NC}      $BACKEND_TYPE"
    echo -e "  ${BLUE}Backend Directory:${NC} $BACKEND_DIR"
    echo -e "  ${BLUE}Image Tag:${NC}         $IMAGE_TAG"
    echo -e "  ${BLUE}AWS Region:${NC}        $AWS_REGION"
    echo -e "  ${BLUE}ECR Repository:${NC}    $REPO_NAME"
    echo ""
}

################################################################################
# Step 1: Run Tests
################################################################################

run_tests() {
    print_header "Step 1: Running Tests (Fail-Fast Validation)"

    print_info "Why tests come first in CI:"
    print_info "  • Fail fast - Don't waste time building if code is broken"
    print_info "  • Quick feedback - Tests run faster than Docker builds"
    print_info "  • Quality gate - Only tested code gets deployed"
    echo ""

    cd "$PROJECT_ROOT/$BACKEND_DIR"

    # Check if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        print_info "Installing Python dependencies..."
        print_command "pip install -q -r requirements.txt"
        echo ""

        print_explain "What this does:"
        print_explain "  • -q = Quiet mode (less verbose output)"
        print_explain "  • Installs Flask, pytest, and other dependencies"
        print_explain "  • Required for tests to run"
        echo ""

        pip install -q -r requirements.txt

        print_success "Dependencies installed"
        echo ""
    else
        print_warning "No requirements.txt found - skipping dependency installation"
        echo ""
    fi

    # Run tests if test directory exists
    if [ -d "tests" ]; then
        print_info "Running pytest test suite..."
        print_command "pytest tests -v"
        echo ""

        print_explain "Test framework: pytest"
        print_explain "  • -v = Verbose mode (shows each test)"
        print_explain "  • Runs all tests in tests/ directory"
        print_explain "  • Exit code 0 = all passed, non-zero = failures"
        echo ""

        print_info "What tests validate:"
        print_info "  • Health endpoint returns {\"status\": \"ok\"}"
        print_info "  • Echo endpoint returns request body"
        print_info "  • Error handling works correctly"
        print_info "  • Response formats are correct"
        echo ""

        # Run pytest
        if pytest tests -v; then
            echo ""
            print_success "All tests passed ✓"
            print_info "Code is ready for Docker build"
        else
            echo ""
            print_error "Tests failed!"
            echo ""
            print_info "CI pipeline stopped (fail-fast principle)"
            print_info "Fix test failures before building Docker image"
            print_info "Review test output above to see what failed"
            exit 1
        fi
    else
        print_warning "No tests directory found - skipping tests"
        print_info "This is not recommended for production pipelines"
        echo ""
    fi

    echo ""
}

################################################################################
# Step 2: Build Docker Image
################################################################################

build_docker_image() {
    print_header "Step 2: Building Docker Image"

    cd "$PROJECT_ROOT"

    print_info "Building Docker container image..."
    print_info "Backend directory: $BACKEND_DIR"
    echo ""

    print_info "Docker build command:"
    print_command "docker build \\"
    print_command "    --platform linux/amd64 \\"
    print_command "    --provenance=false \\"
    print_command "    --sbom=false \\"
    print_command "    -t $REPO_NAME:$IMAGE_TAG \\"
    print_command "    $BACKEND_DIR/"
    echo ""

    print_explain "Parameters explained:"
    print_explain "  • --platform linux/amd64:"
    print_explain "    → Build for x86-64 architecture (Lambda requirement)"
    print_explain "    → Even on Apple M1/M2 (ARM), builds x86-64 image"
    print_explain "    → Lambda only supports x86-64 container images"
    print_explain ""
    print_explain "  • --provenance=false and --sbom=false:"
    print_explain "    → Disables Docker Buildx attestations"
    print_explain "    → Prevents multi-architecture manifest issues"
    print_explain "    → Required for ECR compatibility"
    print_explain ""
    print_explain "  • -t $REPO_NAME:$IMAGE_TAG:"
    print_explain "    → Tags image with name and version"
    print_explain "    → Format: <name>:<tag>"
    print_explain "    → Tag '$IMAGE_TAG' identifies this build"
    print_explain ""
    print_explain "  • $BACKEND_DIR/:"
    print_explain "    → Build context (where Dockerfile is located)"
    print_explain "    → Docker sends this directory to build daemon"
    echo ""

    print_info "What happens during Docker build:"
    print_info "  1. Reads Dockerfile instructions"
    print_info "  2. Pulls base image (python:3.11-slim)"
    print_info "  3. Copies requirements.txt"
    print_info "  4. Installs Python dependencies (Flask, gunicorn)"
    print_info "  5. Copies application source code"
    print_info "  6. Sets up entrypoint (gunicorn server)"
    print_info "  7. Creates final image layers"
    print_info "  8. Tags image for local use"
    echo ""

    print_info "Building (this may take 1-3 minutes)..."
    echo ""

    if docker build \
        --platform linux/amd64 \
        --provenance=false \
        --sbom=false \
        -t $REPO_NAME:$IMAGE_TAG \
        $BACKEND_DIR/; then

        echo ""
        print_success "Docker image built successfully"

        # Show image details
        print_info "Image details:"
        docker images $REPO_NAME:$IMAGE_TAG --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
        echo ""

        # Explain image size
        IMAGE_SIZE=$(docker images $REPO_NAME:$IMAGE_TAG --format "{{.Size}}")
        print_info "Image size: $IMAGE_SIZE"
        print_explain "  • Base image (python:3.11-slim): ~130 MB"
        print_explain "  • Python dependencies: ~20-30 MB"
        print_explain "  • Application code: ~1 MB"
        print_explain "  • Total typically 150-200 MB"
    else
        echo ""
        print_error "Docker build failed"
        echo ""
        print_info "Common issues:"
        print_info "  • Dockerfile syntax error"
        print_info "  • Missing files referenced in Dockerfile"
        print_info "  • Invalid Python dependencies in requirements.txt"
        print_info "  • Docker daemon not running"
        echo ""
        print_info "Check error output above for details"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 3: Get ECR Repository URI
################################################################################

get_ecr_repository() {
    print_header "Step 3: Getting ECR Repository URI"

    print_info "Querying AWS for ECR repository location..."
    echo ""

    print_info "Command:"
    print_command "aws ecr describe-repositories \\"
    print_command "    --repository-names $REPO_NAME \\"
    print_command "    --region $AWS_REGION \\"
    print_command "    --query 'repositories[0].repositoryUri' \\"
    print_command "    --output text"
    echo ""

    ECR_REPO_URI=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null)

    if [ -z "$ECR_REPO_URI" ]; then
        print_error "ECR repository not found"
        echo ""
        print_info "The repository must be created first"
        print_info "Run: ./scripts/jenkins/11-setup-ecr.sh"
        echo ""
        exit 1
    fi

    print_success "ECR Repository: $ECR_REPO_URI"
    echo ""

    print_info "Understanding the URI:"
    echo -e "    ${CYAN}$ECR_REPO_URI${NC}"
    print_explain "    Format: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>"
    print_explain "    This URI is needed to tag and push images"
    echo ""
}

################################################################################
# Step 4: Authenticate Docker to ECR
################################################################################

authenticate_docker() {
    print_header "Step 4: Authenticating Docker to ECR"

    print_info "Docker needs credentials to push images to ECR"
    echo ""

    print_info "Authentication command:"
    print_command "aws ecr get-login-password --region $AWS_REGION | \\"
    print_command "    docker login --username AWS --password-stdin \${ECR_REPO_URI}"
    echo ""

    print_explain "How ECR authentication works:"
    print_explain "  1. 'aws ecr get-login-password' generates temporary password"
    print_explain "     → Uses your AWS credentials (IAM permissions)"
    print_explain "     → Password valid for 12 hours"
    print_explain "     → Different password each time you run it"
    print_explain ""
    print_explain "  2. Password piped to 'docker login' via stdin"
    print_explain "     → Username is always 'AWS' for ECR"
    print_explain "     → Password from step 1 provided via pipe"
    print_explain "     → Docker saves credentials in ~/.docker/config.json"
    print_explain ""
    print_explain "  3. Docker can now push to ECR (until password expires)"
    echo ""

    print_warning "Important: ECR authentication expires after 12 hours"
    print_info "If you get authentication errors later, re-run this script"
    echo ""

    print_info "Authenticating..."

    # Extract registry URL (everything before the repository name)
    ECR_REGISTRY=$(echo $ECR_REPO_URI | cut -d'/' -f1)

    if aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ECR_REGISTRY"; then

        print_success "Docker authenticated to ECR"
        print_info "Authentication valid for 12 hours"
    else
        print_error "ECR login failed"
        echo ""
        print_info "Common issues:"
        print_info "  • AWS credentials expired (Learner Lab session ended)"
        print_info "  • Insufficient IAM permissions (need ECR GetAuthorizationToken)"
        print_info "  • Docker daemon not running"
        print_info "  • Network connectivity issues"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 5: Tag Image for ECR
################################################################################

tag_image() {
    print_header "Step 5: Tagging Image for ECR"

    print_info "Docker images must be tagged with ECR URI before pushing"
    echo ""

    print_info "Tagging commands:"
    print_command "docker tag $REPO_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG"
    print_command "docker tag $REPO_NAME:$IMAGE_TAG $ECR_REPO_URI:latest"
    echo ""

    print_explain "Tagging strategy explained:"
    print_explain "  • Tag 1: $ECR_REPO_URI:$IMAGE_TAG"
    print_explain "    → Specific version tag (e.g., 'manual-test', 'jeffery-123')"
    print_explain "    → Allows tracking specific builds"
    print_explain "    → Can rollback to this version if needed"
    print_explain ""
    print_explain "  • Tag 2: $ECR_REPO_URI:latest"
    print_explain "    → Generic 'latest' tag (always points to newest)"
    print_explain "    → Convenient for development/testing"
    print_explain "    → Not recommended for production (use specific versions)"
    echo ""

    print_info "Understanding Docker tags:"
    print_info "  • Tags are like Git tags - labels for specific versions"
    print_info "  • Same image can have multiple tags"
    print_info "  • Tags don't duplicate data (just metadata pointers)"
    print_info "  • ECR URI in tag tells Docker where to push"
    echo ""

    print_info "Tagging..."

    docker tag $REPO_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG
    docker tag $REPO_NAME:$IMAGE_TAG $ECR_REPO_URI:latest

    print_success "Image tagged for ECR"
    echo ""

    print_info "Tagged images:"
    docker images | grep -E "REPOSITORY|$REPO_NAME|$ECR_REPO_URI" | head -10
    echo ""

    print_explain "Notice: Multiple tags point to same IMAGE ID (not duplicated)"
    echo ""
}

################################################################################
# Step 6: Push Image to ECR
################################################################################

push_image() {
    print_header "Step 6: Pushing Image to ECR"

    print_info "Uploading Docker image to AWS ECR..."
    print_info "This may take 2-5 minutes depending on image size and network speed"
    echo ""

    print_info "Push commands:"
    print_command "docker push $ECR_REPO_URI:$IMAGE_TAG"
    print_command "docker push $ECR_REPO_URI:latest"
    echo ""

    print_explain "What happens during push:"
    print_explain "  1. Docker calculates SHA256 hash for each layer"
    print_explain "  2. Checks which layers already exist in ECR (layer caching)"
    print_explain "  3. Uploads only new/changed layers (saves time and bandwidth)"
    print_explain "  4. ECR stores layers in S3 backend (encrypted at rest)"
    print_explain "  5. ECR scans image for vulnerabilities (if enabled)"
    print_explain "  6. Image becomes available for Lambda deployment"
    echo ""

    print_info "Layer-based push optimization:"
    print_info "  • First push: All layers uploaded (~150-200 MB)"
    print_info "  • Subsequent pushes: Only changed layers uploaded"
    print_info "  • If only code changes: ~1-5 MB upload"
    print_info "  • Base image layers cached in ECR"
    echo ""

    print_info "Pushing $IMAGE_TAG tag..."
    echo ""

    if docker push $ECR_REPO_URI:$IMAGE_TAG; then
        print_success "Pushed: $ECR_REPO_URI:$IMAGE_TAG"
    else
        print_error "Push failed for tag: $IMAGE_TAG"
        exit 1
    fi

    echo ""
    print_info "Pushing latest tag..."
    echo ""

    if docker push $ECR_REPO_URI:latest; then
        print_success "Pushed: $ECR_REPO_URI:latest"
    else
        print_error "Push failed for tag: latest"
        exit 1
    fi

    echo ""
    print_success "Both tags pushed to ECR successfully"
    echo ""
}

################################################################################
# Step 7: Verify Image in ECR
################################################################################

verify_image() {
    print_header "Step 7: Verifying Image in ECR"

    print_info "Confirming image was uploaded correctly..."
    echo ""

    print_info "Verification command:"
    print_command "aws ecr describe-images \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --region $AWS_REGION"
    echo ""

    # Count images
    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'length(imageIds)' \
        --output text 2>/dev/null)

    if [ "$IMAGE_COUNT" -eq 0 ]; then
        print_error "No images found in ECR"
        print_info "Push may have failed silently - check Docker logs"
        exit 1
    fi

    print_success "Found $IMAGE_COUNT image(s) in ECR repository"
    echo ""

    print_info "Recent images (last 5):"
    aws ecr describe-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
        --output table

    echo ""

    # Get image digest
    IMAGE_DIGEST=$(aws ecr describe-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --image-ids imageTag=$IMAGE_TAG \
        --query 'imageDetails[0].imageDigest' \
        --output text 2>/dev/null)

    if [ -n "$IMAGE_DIGEST" ]; then
        print_info "Image digest (SHA256): ${IMAGE_DIGEST:0:20}..."
        print_explain "  • Digest is unique content hash"
        print_explain "  • Same digest = identical image (bit-for-bit)"
        print_explain "  • Used by Lambda to verify image integrity"
    fi

    echo ""
}

################################################################################
# Display Summary and Next Steps
################################################################################

display_summary() {
    print_header "Phase 3a Complete: Manual CI Validated ✅"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     CI PIPELINE SUCCESSFUL - IMAGE IN ECR! ✓                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "What was accomplished:"
    print_info "  ✓ Tests passed (code validated)"
    print_info "  ✓ Docker image built (platform: linux/amd64)"
    print_info "  ✓ Image tagged with version and latest"
    print_info "  ✓ Pushed to ECR repository"
    print_info "  ✓ Verified image exists in ECR"
    echo ""

    echo -e "  ${BLUE}Backend:${NC}     $BACKEND_TYPE"
    echo -e "  ${BLUE}Image Tag:${NC}   $IMAGE_TAG"
    echo -e "  ${BLUE}ECR URI:${NC}     $ECR_REPO_URI"
    echo -e "  ${BLUE}Region:${NC}      $AWS_REGION"
    echo ""

    print_header "Phase 3b: Manual CD Testing (Next)"

    print_info "Now deploy this image to AWS Lambda using SAM:"

    if [ "$BACKEND_TYPE" == "demo-backend" ]; then
        print_command "./scripts/jenkins/31-cd-deploy-sam.sh --demo"
        print_info "(Image tag will be auto-detected from ECR)"
        echo ""
        print_info "Or specify image tag explicitly:"
        print_command "./scripts/jenkins/31-cd-deploy-sam.sh --demo --image-tag $IMAGE_TAG"
    else
        print_command "./scripts/jenkins/31-cd-deploy-sam.sh --prod"
        print_info "(Image tag will be auto-detected from ECR)"
        echo ""
        print_info "Or specify image tag explicitly:"
        print_command "./scripts/jenkins/31-cd-deploy-sam.sh --prod --image-tag $IMAGE_TAG"
    fi

    echo ""

    print_header "Useful Commands"

    print_info "View image in AWS Console:"
    print_info "  1. Open AWS Console → ECR service"
    print_info "  2. Click repository: $REPO_NAME"
    print_info "  3. See image with tags: $IMAGE_TAG, latest"
    echo ""

    print_info "Pull this image to another machine:"
    print_command "aws ecr get-login-password --region $AWS_REGION | \\"
    print_command "    docker login --username AWS --password-stdin $ECR_REGISTRY"
    print_command "docker pull $ECR_REPO_URI:$IMAGE_TAG"
    echo ""

    print_info "Run image locally to test:"
    print_command "docker run -p 8000:8000 $ECR_REPO_URI:$IMAGE_TAG"
    print_command "curl http://localhost:8000/health"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
    run_tests
    build_docker_image
    get_ecr_repository
    authenticate_docker
    tag_image
    push_image
    verify_image
    display_summary

    print_success "Phase 3a: CI pipeline complete!"
    echo ""
}

# Run main function
main "$@"
