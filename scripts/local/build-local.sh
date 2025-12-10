#!/bin/bash

################################################################################
# Local Docker Build Script
################################################################################
#
# Purpose: Build Docker image locally (without AWS ECR)
#
# This script:
# - Builds your Flask app into a Docker image
# - Tags it for local use
# - Same as what Jenkins does in Stage 6
# - Does NOT push to AWS (use scripts/jenkins/20-ci-build-and-push.sh for that)
#
# Use this when you want to:
# - Test Docker image locally before pushing
# - Build without running full Jenkins pipeline
# - Debug Dockerfile issues
#
################################################################################

set -e  # Exit on any error

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
            echo "  --demo    Build demo-backend (Flask validation demo)"
            echo "  --prod    Build backend (production service)"
            echo ""
            echo "You MUST specify either --demo or --prod."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Build demo backend"
            echo "  $0 --prod   # Build production backend"
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
    echo -e "${YELLOW}You must specify which backend to build:${NC}"
    echo ""
    echo "  $0 --demo   # Build demo backend"
    echo "  $0 --prod   # Build production backend"
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
    echo "  $0 --demo   # Build demo backend"
    echo "  $0 --prod   # Build production backend"
    exit 1
fi

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${PIPELINE_IMAGE_NAME:-aws-final-project-repo}"
IMAGE_TAG="local"
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

print_info() {
    echo -e "  $1"
}

################################################################################
# Step 1: Check Prerequisites
################################################################################

check_prerequisites() {
    print_header "Step 1: Checking Prerequisites"

    # Check Docker
    print_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker ps &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
    print_success "Docker is ready"

    # Check Dockerfile exists
    print_info "Checking Dockerfile..."
    if [ ! -f "${BACKEND_DIR}/Dockerfile" ]; then
        print_error "Dockerfile not found at ${BACKEND_DIR}/Dockerfile"
        exit 1
    fi
    print_success "Dockerfile found"

    echo ""
}

################################################################################
# Step 2: Run Tests (Optional but Recommended)
################################################################################

run_tests() {
    print_header "Step 2: Running Tests (Recommended)"

    print_info "It's good practice to run tests before building"
    print_info "This ensures you don't build a broken image"
    echo ""

    read -p "Run tests before building? (Y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Running tests..."

        # Check if test script exists
        if [ -f "${PROJECT_ROOT}/scripts/local/test-local.sh" ]; then
            if [ "$USE_DEMO" = true ]; then
                bash "${PROJECT_ROOT}/scripts/local/test-local.sh" --demo
            else
                bash "${PROJECT_ROOT}/scripts/local/test-local.sh"
            fi
        else
            # Run tests directly
            cd "${BACKEND_DIR}"
            if [ -d ".venv" ]; then
                source .venv/bin/activate
            fi
            pytest tests/ -v || {
                print_error "Tests failed! Fix issues before building."
                exit 1
            }
        fi

        print_success "All tests passed!"
    else
        print_info "Skipping tests (not recommended)"
    fi

    echo ""
}

################################################################################
# Step 3: Build Docker Image
################################################################################

build_image() {
    print_header "Step 3: Building Docker Image"

    print_info "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
    print_info "This will:"
    print_info "  1. Use Python 3.11-slim base image"
    print_info "  2. Install dependencies from requirements.txt"
    print_info "  3. Copy your Flask source code"
    print_info "  4. Configure gunicorn as the WSGI server"
    echo ""

    print_info "Build starting..."
    cd "${BACKEND_DIR}"

    # Build with progress output
    docker build \
        -t "${IMAGE_NAME}:${IMAGE_TAG}" \
        -t "${IMAGE_NAME}:latest" \
        .

    print_success "Docker image built successfully!"

    echo ""
}

################################################################################
# Step 4: Verify Build
################################################################################

verify_build() {
    print_header "Step 4: Verifying Build"

    # Check image exists
    print_info "Checking if image was created..."
    if docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Repository}}:{{.Tag}}" | grep -q "${IMAGE_NAME}:${IMAGE_TAG}"; then
        print_success "Image exists"
    else
        print_error "Image not found"
        exit 1
    fi

    # Display image details
    print_info "Image details:"
    docker images "${IMAGE_NAME}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    echo ""
}

################################################################################
# Step 5: Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    echo -e "${GREEN}Docker image built successfully!${NC}"
    echo ""

    print_info "To run the image locally:"
    echo -e "  ${BLUE}docker run --rm -p 8000:8000 ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
    echo ""

    print_info "To test the running container:"
    echo -e "  ${BLUE}curl http://localhost:8000/health${NC}"
    echo -e "  ${BLUE}curl -X POST http://localhost:8000/echo -H 'Content-Type: application/json' -d '{\"test\":\"data\"}'${NC}"
    echo ""

    print_info "To push to AWS ECR:"
    echo -e "  ${BLUE}./scripts/jenkins/20-ci-build-and-push.sh${NC}"
    echo ""

    print_info "To remove the image:"
    echo -e "  ${BLUE}docker rmi ${IMAGE_NAME}:${IMAGE_TAG}${NC}"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              LOCAL DOCKER BUILD SCRIPT                         ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Builds Flask app into Docker image (local only)              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Building: ${BACKEND_NAME}${NC}"
    echo ""

    check_prerequisites
    run_tests
    build_image
    verify_build
    display_next_steps

    print_success "Build complete!"
    echo ""
}

# Run main function
main "$@"
