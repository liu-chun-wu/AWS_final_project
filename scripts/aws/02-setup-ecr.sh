#!/bin/bash

################################################################################
# AWS ECR Repository Setup Script
################################################################################
#
# Purpose: Create AWS ECR (Elastic Container Registry) repository
#
# What is ECR?
# - AWS's Docker container registry (like Docker Hub, but private and in AWS)
# - Stores your Docker images securely
# - Required for Lambda container-based functions
# - Images stay in AWS (fast access for Lambda)
#
# This script:
# - Creates ECR repository (if doesn't exist)
# - Configures image scanning for security
# - Displays repository URI
# - Saves configuration for other scripts
#
# You only need to run this ONCE per project!
#
# What you'll learn:
# - How to create ECR repositories
# - How to check if resources already exist
# - How to get repository details
# - How ECR URIs work
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

# Configuration
REPOSITORY_NAME="aws-lab-flask-demo"
AWS_REGION="us-east-1"

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
# Step 1: Get AWS Account ID
################################################################################

get_account_id() {
    print_header "Step 1: Getting AWS Account ID"

    print_info "Every ECR repository URI includes your AWS account ID"
    print_info "Format: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>"
    echo ""

    print_info "Command to get your account ID:"
    print_command "aws sts get-caller-identity --query Account --output text"
    print_explain "  - 'sts' = Security Token Service"
    print_explain "  - '--query Account' = Extract only the Account field from JSON"
    print_explain "  - '--output text' = Return plain text (not JSON)"
    echo ""

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

    if [ -z "$ACCOUNT_ID" ]; then
        print_error "Failed to get AWS account ID"
        print_info "Make sure AWS credentials are configured"
        print_info "Run: ./scripts/aws/01-check-prerequisites.sh"
        exit 1
    fi

    print_success "AWS Account ID: ${ACCOUNT_ID}"
    echo ""
}

################################################################################
# Step 2: Check if Repository Already Exists
################################################################################

check_repository_exists() {
    print_header "Step 2: Checking if Repository Exists"

    print_info "Before creating, we check if the repository already exists"
    print_info "This makes the script idempotent (safe to run multiple times)"
    echo ""

    print_info "Command to describe ECR repository:"
    print_command "aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION}"
    print_explain "  - 'ecr' = Elastic Container Registry service"
    print_explain "  - 'describe-repositories' = Get repository details"
    print_explain "  - '--repository-names' = Filter by specific repository name"
    print_explain "  - If repository doesn't exist, this command returns an error"
    echo ""

    print_info "Checking for repository '${REPOSITORY_NAME}'..."

    if aws ecr describe-repositories \
        --repository-names "${REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        &> /dev/null; then

        print_warning "Repository already exists"
        REPOSITORY_EXISTS=true
    else
        print_info "Repository not found (will create)"
        REPOSITORY_EXISTS=false
    fi

    echo ""
}

################################################################################
# Step 3: Create Repository (if needed)
################################################################################

create_repository() {
    print_header "Step 3: Creating ECR Repository"

    if [ "$REPOSITORY_EXISTS" = true ]; then
        print_warning "Skipping creation - repository already exists"
        echo ""
        return
    fi

    print_info "Creating new ECR repository..."
    echo ""

    print_info "Command to create ECR repository:"
    print_command "aws ecr create-repository \\"
    print_command "  --repository-name ${REPOSITORY_NAME} \\"
    print_command "  --region ${AWS_REGION} \\"
    print_command "  --image-scanning-configuration scanOnPush=true"
    echo ""

    print_explain "Parameters explained:"
    print_explain "  --repository-name: Name of your Docker repository"
    print_explain "  --region: AWS region (us-east-1 for Learner Lab)"
    print_explain "  --image-scanning-configuration scanOnPush=true:"
    print_explain "    - Automatically scans images for vulnerabilities when pushed"
    print_explain "    - AWS checks for known security issues"
    print_explain "    - Free feature, highly recommended"
    echo ""

    print_info "Creating repository..."

    CREATE_OUTPUT=$(aws ecr create-repository \
        --repository-name "${REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        --image-scanning-configuration scanOnPush=true \
        2>&1)

    if [ $? -eq 0 ]; then
        print_success "Repository created successfully!"
    else
        print_error "Failed to create repository"
        echo "$CREATE_OUTPUT"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 4: Get Repository Details
################################################################################

get_repository_details() {
    print_header "Step 4: Getting Repository Details"

    print_info "Retrieving repository information..."
    echo ""

    print_info "Command to get repository URI:"
    print_command "aws ecr describe-repositories \\"
    print_command "  --repository-names ${REPOSITORY_NAME} \\"
    print_command "  --region ${AWS_REGION} \\"
    print_command "  --query 'repositories[0].repositoryUri' \\"
    print_command "  --output text"
    echo ""

    print_explain "What this does:"
    print_explain "  --query 'repositories[0].repositoryUri':"
    print_explain "    - Extracts just the URI from the JSON response"
    print_explain "    - repositories[0] = first repository in the array"
    print_explain "    - .repositoryUri = the URI field"
    echo ""

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --repository-names "${REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryUri' \
        --output text)

    if [ -z "$REPOSITORY_URI" ]; then
        print_error "Failed to get repository URI"
        exit 1
    fi

    REPOSITORY_ARN=$(aws ecr describe-repositories \
        --repository-names "${REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryArn' \
        --output text)

    print_success "Repository details retrieved"
    echo ""

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ECR REPOSITORY INFORMATION                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BLUE}Repository Name:${NC}  ${REPOSITORY_NAME}"
    echo -e "  ${BLUE}Repository URI:${NC}   ${REPOSITORY_URI}"
    echo -e "  ${BLUE}Repository ARN:${NC}   ${REPOSITORY_ARN}"
    echo -e "  ${BLUE}AWS Region:${NC}       ${AWS_REGION}"
    echo ""

    print_info "Understanding the URI:"
    echo -e "    ${CYAN}${ACCOUNT_ID}${NC}.dkr.ecr.${CYAN}${AWS_REGION}${NC}.amazonaws.com/${CYAN}${REPOSITORY_NAME}${NC}"
    print_explain "    └─ Account  └─ Region                    └─ Repository"
    echo ""
}

################################################################################
# Step 5: List Images (if any)
################################################################################

list_images() {
    print_header "Step 5: Checking for Existing Images"

    print_info "Command to list images in repository:"
    print_command "aws ecr list-images --repository-name ${REPOSITORY_NAME} --region ${AWS_REGION}"
    print_explain "  - Shows all Docker images currently stored in this repository"
    print_explain "  - Each image can have multiple tags (like 'latest', '1', '2', etc.)"
    echo ""

    print_info "Checking for images..."

    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name "${REPOSITORY_NAME}" \
        --region "${AWS_REGION}" \
        --query 'length(imageIds)' \
        --output text)

    if [ "$IMAGE_COUNT" -eq 0 ]; then
        print_info "No images in repository yet"
        print_info "Images will be added when you run: ./scripts/aws/03-build-and-push.sh"
    else
        print_success "Found ${IMAGE_COUNT} image(s) in repository"

        print_info "Listing images:"
        aws ecr list-images \
            --repository-name "${REPOSITORY_NAME}" \
            --region "${AWS_REGION}" \
            --output table
    fi

    echo ""
}

################################################################################
# Step 6: Save Configuration
################################################################################

save_configuration() {
    print_header "Step 6: Saving Configuration"

    print_info "Saving ECR URI for use in other scripts..."

    # Create .env file if it doesn't exist
    ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"

    # Check if .env exists
    if [ -f "$ENV_FILE" ]; then
        # Update existing ECR_URI
        if grep -q "^ECR_URI=" "$ENV_FILE"; then
            sed -i.bak "s|^ECR_URI=.*|ECR_URI=${REPOSITORY_URI}|" "$ENV_FILE"
            print_info "Updated ECR_URI in existing .env file"
        else
            echo "ECR_URI=${REPOSITORY_URI}" >> "$ENV_FILE"
            print_info "Added ECR_URI to existing .env file"
        fi
    else
        # Create new .env file
        cat > "$ENV_FILE" << EOF
# AWS Configuration
# Generated by scripts/aws/02-setup-ecr.sh

# ECR Repository URI
ECR_URI=${REPOSITORY_URI}

# AWS Region
AWS_REGION=${AWS_REGION}

# AWS Account ID
AWS_ACCOUNT_ID=${ACCOUNT_ID}
EOF
        print_info "Created new .env file with ECR configuration"
    fi

    print_success "Configuration saved to: ${ENV_FILE}"
    echo ""

    print_info "Other scripts can now use:"
    print_command "source .env"
    print_command "echo \$ECR_URI    # Shows: ${REPOSITORY_URI}"
    echo ""
}

################################################################################
# Step 7: Display Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    echo -e "${GREEN}ECR repository is ready!${NC}"
    echo ""

    print_info "What you just created:"
    print_info "  ✓ ECR repository: ${REPOSITORY_NAME}"
    print_info "  ✓ Image scanning: Enabled (scans on push)"
    print_info "  ✓ Repository URI: ${REPOSITORY_URI}"
    echo ""

    print_info "To push your Docker image to this repository:"
    print_command "./scripts/aws/03-build-and-push.sh"
    print_info "  - Builds your Flask app into a Docker image"
    print_info "  - Authenticates Docker to ECR"
    print_info "  - Tags image with ECR URI"
    print_info "  - Pushes image to this repository"
    echo ""

    print_info "To check images in the repository:"
    print_command "aws ecr list-images --repository-name ${REPOSITORY_NAME} --region ${AWS_REGION}"
    echo ""

    print_info "To view repository in AWS Console:"
    print_info "  1. Open AWS Console"
    print_info "  2. Go to ECR (Elastic Container Registry)"
    print_info "  3. Find repository: ${REPOSITORY_NAME}"
    echo ""

    print_info "To delete the repository (when done):"
    print_command "./scripts/aws/99-cleanup-all.sh"
    print_info "  - Or manually: aws ecr delete-repository --repository-name ${REPOSITORY_NAME} --force"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              ECR REPOSITORY SETUP                              ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Creates AWS ECR repository for Docker images                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "What is ECR?"
    print_info "  - AWS's private Docker container registry"
    print_info "  - Like Docker Hub, but integrated with AWS"
    print_info "  - Required for Lambda container-based functions"
    print_info "  - Stores your Docker images securely in AWS"
    echo ""

    get_account_id
    check_repository_exists
    create_repository
    get_repository_details
    list_images
    save_configuration
    display_next_steps

    print_success "ECR setup complete!"
    echo ""
}

# Run main function
main "$@"
