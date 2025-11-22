#!/bin/bash

################################################################################
# Docker Build and Push to ECR Script
################################################################################
#
# Purpose: Build Docker image and push to AWS ECR
#
# This script:
# - Builds your Flask app into a Docker image
# - Authenticates Docker client to AWS ECR
# - Tags image with ECR repository URI
# - Pushes image to ECR
# - Verifies the push succeeded
#
# Run this whenever you update your code and want to deploy to AWS!
#
# What you'll learn:
# - How to authenticate Docker to AWS ECR
# - How Docker image tagging works
# - How to push images to ECR
# - How to verify images were uploaded correctly
# - Understanding ECR authentication (expires after 12 hours)
#
################################################################################

set -e  # Exit on any error

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse command-line arguments
BACKEND_SPECIFIED=false
USE_DEMO=false
USE_PROD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --demo)
            BACKEND_SPECIFIED=true
            USE_DEMO=true
            shift
            ;;
        --prod)
            BACKEND_SPECIFIED=true
            USE_PROD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 --demo|--prod"
            echo ""
            echo "Backend Selection (REQUIRED):"
            echo "  --demo    Build and push demo-backend (Flask validation demo)"
            echo "  --prod    Build and push backend (production service)"
            echo ""
            echo "You MUST specify either --demo or --prod."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Build and push demo backend"
            echo "  $0 --prod   # Build and push production backend"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            echo ""
            echo "Usage: $0 --demo|--prod"
            echo "Use --help for more information"
            exit 1
            ;;
    esac
done

# Validate that exactly one backend was specified
if [ "$BACKEND_SPECIFIED" = false ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Backend not specified                                  ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}You must specify which backend to build and push:${NC}"
    echo ""
    echo "  $0 --demo   # Build and push demo backend"
    echo "  $0 --prod   # Build and push production backend"
    echo ""
    echo "Use --help for more information"
    exit 1
fi

if [ "$USE_DEMO" = true ] && [ "$USE_PROD" = true ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Conflicting flags                                      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}You cannot specify both --demo and --prod${NC}"
    echo ""
    echo "Choose exactly one:"
    echo "  $0 --demo   # Build and push demo backend"
    echo "  $0 --prod   # Build and push production backend"
    exit 1
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="aws-lab-flask-demo"
AWS_REGION="us-east-1"

# Set backend directory based on flag
if [ "$USE_DEMO" = true ]; then
    BACKEND_DIR="${PROJECT_ROOT}/demo-backend"
    BACKEND_NAME="demo-backend"
elif [ "$USE_PROD" = true ]; then
    BACKEND_DIR="${PROJECT_ROOT}/backend"
    BACKEND_NAME="backend"
else
    # This should never happen due to validation above
    echo "FATAL ERROR: Invalid backend state"
    exit 1
fi

################################################################################
# Helper Functions
################################################################################

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
    echo -e "${CYAN}  $ $1${NC}"
}

print_explain() {
    echo -e "${YELLOW}  ℹ $1${NC}"
}

################################################################################
# Step 1: Get ECR Repository URI
################################################################################

get_ecr_uri() {
    print_header "Step 1: Getting ECR Repository Information"

    print_info "We need to know where to push the Docker image"
    echo ""

    # Try to load from .env file first
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        print_info "Loading ECR URI from .env file..."
        source "${PROJECT_ROOT}/.env"

        if [ -n "$ECR_URI" ]; then
            print_success "Loaded ECR_URI from .env: ${ECR_URI}"
            REPOSITORY_URI=$ECR_URI
            echo ""
            return
        fi
    fi

    # If not in .env, query AWS
    print_info "Querying AWS for ECR repository URI..."
    echo ""

    print_info "Command to get ECR repository URI:"
    print_command "aws ecr describe-repositories \\"
    print_command "  --repository-names ${IMAGE_NAME} \\"
    print_command "  --region ${AWS_REGION} \\"
    print_command "  --query 'repositories[0].repositoryUri' \\"
    print_command "  --output text"
    echo ""

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --repository-names "${IMAGE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null)

    if [ -z "$REPOSITORY_URI" ] || [ "$REPOSITORY_URI" = "None" ]; then
        print_error "ECR repository not found"
        print_info "You need to create the ECR repository first"
        print_info "Run: ./scripts/aws/02-setup-ecr.sh"
        exit 1
    fi

    print_success "ECR Repository URI: ${REPOSITORY_URI}"
    echo ""
}

################################################################################
# Step 2: Run Tests
################################################################################

run_tests() {
    print_header "Step 2: Running Tests"

    print_info "It's important to test your code before building and deploying"
    print_info "This prevents deploying broken code to AWS"
    echo ""

    read -p "Run tests before building? (Y/n): " -n 1 -r
    echo ""
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        if [ -f "${PROJECT_ROOT}/scripts/local/test-local.sh" ]; then
            print_info "Running test script..."
            if [ "$USE_DEMO" = true ]; then
                bash "${PROJECT_ROOT}/scripts/local/test-local.sh" --demo
            else
                bash "${PROJECT_ROOT}/scripts/local/test-local.sh"
            fi
        else
            print_info "Running pytest directly..."
            cd "${BACKEND_DIR}"

            if [ -d ".venv" ]; then
                source .venv/bin/activate
            fi

            pytest tests/ -v || {
                print_error "Tests failed! Fix issues before deploying."
                exit 1
            }
        fi

        print_success "All tests passed!"
    else
        print_warning "Skipping tests (not recommended)"
    fi

    echo ""
}

################################################################################
# Step 3: Build Docker Image
################################################################################

build_docker_image() {
    print_header "Step 3: Building Docker Image"

    print_info "Building Docker image from Dockerfile..."
    print_info "Backend: ${BACKEND_NAME}"
    echo ""

    print_info "Command to build Docker image:"
    print_command "docker build -t ${IMAGE_NAME}:latest ${BACKEND_DIR}/"
    print_explain "  -t = tag the image with a name"
    print_explain "  ${IMAGE_NAME}:latest = image name and tag"
    print_explain "  ${BACKEND_DIR}/ = build context (where Dockerfile is)"
    echo ""

    print_info "What happens during build:"
    print_info "  1. Pulls Python 3.11-slim base image"
    print_info "  2. Copies requirements.txt"
    print_info "  3. Installs Python dependencies (Flask, gunicorn, pytest)"
    print_info "  4. Copies your Flask source code"
    print_info "  5. Sets up gunicorn as the WSGI server"
    echo ""

    print_info "Building..."

    cd "${BACKEND_DIR}"
    docker build -t "${IMAGE_NAME}:latest" .

    print_success "Docker image built successfully"

    # Display image info
    print_info "Image details:"
    docker images "${IMAGE_NAME}:latest" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    echo ""
}

################################################################################
# Step 4: Authenticate Docker to ECR
################################################################################

authenticate_docker() {
    print_header "Step 4: Authenticating Docker to ECR"

    print_info "Docker needs to authenticate to ECR before pushing images"
    print_info "This is like logging in to Docker Hub, but for AWS ECR"
    echo ""

    print_info "Command to authenticate Docker to ECR:"
    print_command "aws ecr get-login-password --region ${AWS_REGION} | \\"
    print_command "  docker login --username AWS --password-stdin \${ECR_REGISTRY}"
    echo ""

    print_explain "How this works:"
    print_explain "  1. 'aws ecr get-login-password' - Gets a temporary password from ECR"
    print_explain "     - Password is valid for 12 hours"
    print_explain "     - Generated from your AWS credentials"
    print_explain "  2. '| docker login' - Pipes the password to Docker login"
    print_explain "     - Username is always 'AWS' for ECR"
    print_explain "     - Password comes from stdin (the pipe)"
    print_explain "  3. Docker saves credentials in ~/.docker/config.json"
    echo ""

    print_info "Authenticating..."

    # Extract registry URL from repository URI
    # URI format: <account>.dkr.ecr.<region>.amazonaws.com/<repo-name>
    # Registry: <account>.dkr.ecr.<region>.amazonaws.com
    ECR_REGISTRY=$(echo $REPOSITORY_URI | cut -d'/' -f1)

    print_info "ECR Registry: ${ECR_REGISTRY}"

    aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login --username AWS --password-stdin "${ECR_REGISTRY}"

    print_success "Docker authenticated to ECR"

    print_warning "Note: This authentication expires after 12 hours"
    print_info "If you get authentication errors later, run this script again"

    echo ""
}

################################################################################
# Step 5: Tag Image for ECR
################################################################################

tag_image() {
    print_header "Step 5: Tagging Image for ECR"

    print_info "Docker images need to be tagged with the ECR repository URI before pushing"
    echo ""

    print_info "Command to tag image:"
    print_command "docker tag ${IMAGE_NAME}:latest ${REPOSITORY_URI}:latest"
    echo ""

    print_explain "Understanding Docker tags:"
    print_explain "  Local tag:  ${IMAGE_NAME}:latest"
    print_explain "  ECR tag:    ${REPOSITORY_URI}:latest"
    print_explain ""
    print_explain "  The ECR tag tells Docker where to push the image"
    print_explain "  Format: <registry>/<repository>:<tag>"
    print_explain "  Example: 123456.dkr.ecr.us-east-1.amazonaws.com/aws-lab-flask-demo:latest"
    echo ""

    print_info "Tagging image..."

    docker tag "${IMAGE_NAME}:latest" "${REPOSITORY_URI}:latest"

    print_success "Image tagged for ECR"

    print_info "Image tags:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}"
    docker images "${REPOSITORY_URI}" --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null || true

    echo ""
}

################################################################################
# Step 6: Push Image to ECR
################################################################################

push_image() {
    print_header "Step 6: Pushing Image to ECR"

    print_info "Uploading Docker image to AWS ECR..."
    print_info "This may take a few minutes depending on image size and internet speed"
    echo ""

    print_info "Command to push image:"
    print_command "docker push ${REPOSITORY_URI}:latest"
    echo ""

    print_explain "What happens during push:"
    print_explain "  1. Docker calculates checksums for each image layer"
    print_explain "  2. Checks which layers already exist in ECR (saves time)"
    print_explain "  3. Uploads only new/changed layers (incremental upload)"
    print_explain "  4. ECR scans the image for vulnerabilities (if enabled)"
    print_explain "  5. Image becomes available for Lambda to use"
    echo ""

    print_info "Pushing..."
    echo ""

    docker push "${REPOSITORY_URI}:latest"

    echo ""
    print_success "Image pushed to ECR successfully!"

    echo ""
}

################################################################################
# Step 7: Verify Push
################################################################################

verify_push() {
    print_header "Step 7: Verifying Image in ECR"

    print_info "Confirming image was uploaded correctly..."
    echo ""

    print_info "Command to list images in ECR:"
    print_command "aws ecr describe-images \\"
    print_command "  --repository-name ${IMAGE_NAME} \\"
    print_command "  --region ${AWS_REGION}"
    echo ""

    print_info "Querying ECR..."

    IMAGE_INFO=$(aws ecr describe-images \
        --repository-name "${IMAGE_NAME}" \
        --region "${AWS_REGION}" \
        --output json)

    IMAGE_COUNT=$(echo "$IMAGE_INFO" | grep -c "imageDigest" || echo "0")

    if [ "$IMAGE_COUNT" -eq 0 ]; then
        print_error "No images found in ECR"
        print_info "Push may have failed. Check Docker logs."
        exit 1
    fi

    print_success "Found ${IMAGE_COUNT} image(s) in ECR"

    print_info "Latest image details:"
    aws ecr describe-images \
        --repository-name "${IMAGE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'reverse(sort_by(imageDetails, &imagePushedAt))[0]' \
        --output table

    echo ""

    # Get image digest
    IMAGE_DIGEST=$(echo "$IMAGE_INFO" | grep -o '"imageDigest"[^}]*' | head -1 | cut -d'"' -f4)
    print_info "Image digest: ${IMAGE_DIGEST}"

    # Get image size
    IMAGE_SIZE=$(aws ecr describe-images \
        --repository-name "${IMAGE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'reverse(sort_by(imageDetails, &imagePushedAt))[0].imageSizeInBytes' \
        --output text)

    IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
    print_info "Image size: ${IMAGE_SIZE_MB} MB"

    echo ""
}

################################################################################
# Step 8: Display Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          DOCKER IMAGE PUSHED TO ECR! ✓                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Your Docker image is now in AWS ECR:"
    echo -e "  ${BLUE}Repository:${NC} ${REPOSITORY_URI}"
    echo -e "  ${BLUE}Tag:${NC}        latest"
    echo -e "  ${BLUE}Size:${NC}       ${IMAGE_SIZE_MB} MB"
    echo ""

    print_info "To deploy this image to AWS Lambda:"
    print_command "./scripts/aws/04-deploy-sam.sh"
    print_info "  - Creates Lambda function using this image"
    print_info "  - Sets up API Gateway"
    print_info "  - Configures CloudWatch logging"
    echo ""

    print_info "To view the image in AWS Console:"
    print_info "  1. Open AWS Console"
    print_info "  2. Go to ECR (Elastic Container Registry)"
    print_info "  3. Click on repository: ${IMAGE_NAME}"
    print_info "  4. See image with tag 'latest'"
    echo ""

    print_info "To check for security vulnerabilities:"
    print_command "aws ecr describe-image-scan-findings \\"
    print_command "  --repository-name ${IMAGE_NAME} \\"
    print_command "  --image-id imageTag=latest \\"
    print_command "  --region ${AWS_REGION}"
    echo ""

    print_info "To delete the image (if needed):"
    print_command "aws ecr batch-delete-image \\"
    print_command "  --repository-name ${IMAGE_NAME} \\"
    print_command "  --image-ids imageTag=latest \\"
    print_command "  --region ${AWS_REGION}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         BUILD AND PUSH DOCKER IMAGE TO ECR                     ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Builds Flask app and uploads to AWS container registry       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Backend: ${BACKEND_NAME}${NC}"
    echo ""

    get_ecr_uri
    run_tests
    build_docker_image
    authenticate_docker
    tag_image
    push_image
    verify_push
    display_next_steps

    print_success "Build and push complete!"
    echo ""
}

# Run main function
main "$@"
