#!/bin/bash

################################################################################
# AWS ECR Repository Setup Script
################################################################################
#
# Script: 11-setup-ecr.sh
# Purpose: Create Amazon ECR (Elastic Container Registry) repository for Flask demo
#
# What is ECR?
# - AWS's managed Docker container registry service (like Docker Hub, but private)
# - Stores your Docker images securely in AWS
# - Required for Lambda container-based functions
# - Images stay in AWS (fast access for Lambda, no external pulls)
# - Integrated with AWS IAM for access control
#
# This script:
# - Creates ECR repository if it doesn't exist (idempotent)
# - Configures automatic image scanning for security vulnerabilities
# - Displays repository URI for use in other scripts
# - Saves repository URI to file for automation
#
# You only need to run this ONCE per project!
#
# What you'll learn:
# - How to create ECR repositories with AWS CLI
# - How to check if AWS resources already exist (idempotent design)
# - How to extract specific fields from JSON responses (JMESPath queries)
# - Understanding ECR repository URI structure
# - How image scanning works in ECR
#
# AWS Services Used:
# - ECR (Elastic Container Registry) - Container image storage
# - STS (Security Token Service) - Get AWS account ID
#
# Prerequisites:
# - AWS CLI configured with valid credentials
# - Appropriate IAM permissions for ECR operations
#
# Cost:
# - ECR storage: ~$0.10 per GB per month
# - Data transfer: Free within same region to Lambda
# - Image scanning: Free feature
#
################################################################################

set -e  # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env-common.sh"
REPO_NAME="${PIPELINE_ECR_REPO:-aws-final-project-repo}"
AWS_REGION="${PIPELINE_AWS_REGION:-us-east-1}"

################################################################################
# Helper Functions for Output Formatting
################################################################################

# Color codes for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

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
# Step 1: Display Introduction
################################################################################

show_introduction() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              ECR REPOSITORY SETUP                              ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Creates AWS ECR repository for Docker container images       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is Amazon ECR?"

    print_info "Amazon Elastic Container Registry (ECR) is AWS's Docker image registry:"
    print_info "  • Like Docker Hub, but fully managed by AWS"
    print_info "  • Private by default (only your AWS account can access)"
    print_info "  • Integrated with AWS Lambda for container deployments"
    print_info "  • Automatic vulnerability scanning for security"
    print_info "  • High availability and durability for images"
    echo ""

    print_info "Why do we need ECR?"
    print_info "  • Lambda container functions require images in ECR (same region)"
    print_info "  • Fast image pulls (no internet dependency)"
    print_info "  • IAM-based access control (secure)"
    print_info "  • Automatic encryption at rest"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}Repository Name:${NC} $REPO_NAME"
    echo -e "  ${BLUE}AWS Region:${NC}      $AWS_REGION"
    echo ""
}

################################################################################
# Step 2: Get AWS Account ID
################################################################################

get_account_id() {
    print_header "Step 1: Getting AWS Account ID"

    print_info "Every ECR repository URI includes your AWS account ID"
    print_info "Format: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>"
    echo ""

    print_info "Command to get your AWS account ID:"
    print_command "aws sts get-caller-identity --query Account --output text"
    echo ""

    print_explain "Understanding this command:"
    print_explain "  • 'aws sts' = AWS Security Token Service"
    print_explain "  • 'get-caller-identity' = Returns details about the IAM identity"
    print_explain "  • '--query Account' = Extract only the Account field using JMESPath"
    print_explain "  • '--output text' = Return plain text instead of JSON"
    echo ""

    print_info "Retrieving account ID..."

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>&1)

    if [ $? -ne 0 ]; then
        print_error "Failed to get AWS account ID"
        echo ""
        print_info "This usually means:"
        print_info "  • AWS credentials are not configured"
        print_info "  • AWS credentials have expired (Learner Lab sessions expire)"
        print_info "  • No internet connection to AWS services"
        echo ""
        print_info "For AWS Learner Lab users:"
        print_info "  1. Open your Learner Lab in Canvas/AWS Academy"
        print_info "  2. Click 'Start Lab' and wait for green indicator"
        print_info "  3. Click 'AWS Details' → 'Show' next to AWS CLI credentials"
        print_info "  4. Copy the credentials to ~/.aws/credentials"
        echo ""
        exit 1
    fi

    if [ -z "$ACCOUNT_ID" ]; then
        print_error "Account ID is empty"
        exit 1
    fi

    print_success "AWS Account ID: ${ACCOUNT_ID}"
    echo ""
}

################################################################################
# Step 3: Check if Repository Already Exists
################################################################################

check_repository_exists() {
    print_header "Step 2: Checking if ECR Repository Exists"

    print_info "Before creating a resource, we check if it already exists"
    print_info "This makes the script 'idempotent' - safe to run multiple times"
    echo ""

    print_info "Command to check for existing repository:"
    print_command "aws ecr describe-repositories \\"
    print_command "    --repository-names $REPO_NAME \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_explain "Understanding this command:"
    print_explain "  • 'aws ecr' = Elastic Container Registry service"
    print_explain "  • 'describe-repositories' = Get repository details"
    print_explain "  • '--repository-names' = Filter by specific repository name"
    print_explain "  • '--region' = AWS region (us-east-1 for Learner Lab)"
    print_explain "  • If repository doesn't exist, this returns an error (exit code ≠ 0)"
    echo ""

    print_info "Checking for repository '$REPO_NAME'..."

    if aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" &>/dev/null; then

        print_warning "Repository already exists (this is okay!)"
        print_info "The script will use the existing repository"
        REPOSITORY_EXISTS=true
    else
        print_info "Repository not found - will create new one"
        REPOSITORY_EXISTS=false
    fi

    echo ""
}

################################################################################
# Step 4: Create Repository (if needed)
################################################################################

create_repository() {
    print_header "Step 3: Creating ECR Repository"

    if [ "$REPOSITORY_EXISTS" = true ]; then
        print_warning "Skipping creation - repository already exists"
        print_info "Using existing repository: $REPO_NAME"
        echo ""
        return
    fi

    print_info "Creating new ECR repository with security features..."
    echo ""

    print_info "Command to create ECR repository:"
    print_command "aws ecr create-repository \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --region $AWS_REGION \\"
    print_command "    --image-scanning-configuration scanOnPush=true"
    echo ""

    print_explain "Parameters explained:"
    print_explain "  • --repository-name: Unique name for your Docker repository"
    print_explain "  • --region: AWS region where repository will be created"
    print_explain "  • --image-scanning-configuration scanOnPush=true:"
    print_explain "    → Automatically scans images for vulnerabilities when pushed"
    print_explain "    → AWS checks against CVE database (Common Vulnerabilities)"
    print_explain "    → Scan results available in ECR console"
    print_explain "    → Free feature, highly recommended for production"
    echo ""

    print_info "What happens during creation:"
    print_info "  1. AWS creates the repository metadata"
    print_info "  2. Sets up storage backend for image layers"
    print_info "  3. Configures encryption at rest (automatic)"
    print_info "  4. Enables vulnerability scanning"
    print_info "  5. Returns repository ARN and URI"
    echo ""

    print_info "Creating repository..."

    CREATE_OUTPUT=$(aws ecr create-repository \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --image-scanning-configuration scanOnPush=true \
        2>&1)

    if [ $? -eq 0 ]; then
        print_success "Repository created successfully!"
    else
        print_error "Failed to create repository"
        echo ""
        print_info "Error details:"
        echo "$CREATE_OUTPUT"
        echo ""
        print_info "Common issues:"
        print_info "  • Repository name already exists (check for typos)"
        print_info "  • Insufficient IAM permissions (check ECR policies)"
        print_info "  • Region quota limit reached (unlikely in Learner Lab)"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 5: Get Repository Details
################################################################################

get_repository_details() {
    print_header "Step 4: Getting Repository Details"

    print_info "Retrieving repository information from AWS..."
    echo ""

    print_info "Command to get repository URI:"
    print_command "aws ecr describe-repositories \\"
    print_command "    --repository-names $REPO_NAME \\"
    print_command "    --region $AWS_REGION \\"
    print_command "    --query 'repositories[0].repositoryUri' \\"
    print_command "    --output text"
    echo ""

    print_explain "Understanding the query:"
    print_explain "  • 'repositories[0]' = First repository in the array"
    print_explain "  • '.repositoryUri' = Extract the URI field"
    print_explain "  • JMESPath query extracts exact field from JSON response"
    echo ""

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text)

    if [ -z "$REPOSITORY_URI" ]; then
        print_error "Failed to get repository URI"
        print_info "This should not happen if repository exists"
        exit 1
    fi

    REPOSITORY_ARN=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryArn' \
        --output text)

    print_success "Repository details retrieved"
    echo ""

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ECR REPOSITORY INFORMATION                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${BLUE}Repository Name:${NC}  $REPO_NAME"
    echo -e "  ${BLUE}Repository URI:${NC}   $REPOSITORY_URI"
    echo -e "  ${BLUE}Repository ARN:${NC}   $REPOSITORY_ARN"
    echo -e "  ${BLUE}AWS Region:${NC}       $AWS_REGION"
    echo ""

    print_info "Understanding the ECR URI:"
    echo -e "    ${CYAN}${ACCOUNT_ID}${NC}.dkr.ecr.${CYAN}${AWS_REGION}${NC}.amazonaws.com/${CYAN}${REPO_NAME}${NC}"
    print_explain "    └─ Account  └─ Region                    └─ Repository"
    echo ""

    print_explain "This URI is used to:"
    print_explain "  • Tag Docker images before pushing"
    print_explain "  • Authenticate Docker client to ECR"
    print_explain "  • Reference in SAM templates for Lambda"
    echo ""
}

################################################################################
# Step 6: List Existing Images (if any)
################################################################################

list_images() {
    print_header "Step 5: Checking for Existing Images"

    print_info "Command to list images in repository:"
    print_command "aws ecr list-images \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_explain "What this shows:"
    print_explain "  • All Docker images currently stored in this repository"
    print_explain "  • Each image can have multiple tags (like 'latest', 'v1.0', 'manual-test')"
    print_explain "  • Images are identified by digest (SHA256 hash)"
    echo ""

    print_info "Querying repository..."

    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'length(imageIds)' \
        --output text 2>/dev/null)

    if [ "$IMAGE_COUNT" -eq 0 ]; then
        print_info "No images in repository yet"
        print_info "Images will be added when you run Phase 3a (Manual CI Testing):"
        print_command "./scripts/jenkins/20-ci-build-and-push.sh --demo"
    else
        print_success "Found $IMAGE_COUNT image(s) in repository"
        echo ""

        print_info "Recent images:"
        aws ecr describe-images \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
            --output table
    fi

    echo ""
}

################################################################################
# Step 7: Save Configuration for Other Scripts
################################################################################

save_configuration() {
    print_header "Step 6: Saving Configuration"

    print_info "Saving ECR repository URI for use in other scripts..."
    echo ""

    # Save to .ecr-repo-uri file (used by other scripts)
    ECR_URI_FILE="$SCRIPT_DIR/.ecr-repo-uri"
    echo "$REPOSITORY_URI" > "$ECR_URI_FILE"

    print_success "Repository URI saved to: $ECR_URI_FILE"
    echo ""

    print_info "Other scripts can load this URI with:"
    print_command "REPO_URI=\$(cat $ECR_URI_FILE)"
    echo ""
}

################################################################################
# Step 8: Display Next Steps
################################################################################

display_next_steps() {
    print_header "Next Steps"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          ECR REPOSITORY IS READY! ✓                           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "What you just created:"
    print_info "  ✓ ECR repository: $REPO_NAME"
    print_info "  ✓ Image scanning: Enabled (scans on push for vulnerabilities)"
    print_info "  ✓ Repository URI: $REPOSITORY_URI"
    print_info "  ✓ Configuration saved for automation"
    echo ""

    print_header "Phase 3a: Manual CI Testing (Next)"

    print_info "Now you can build and push Docker images to ECR:"
    print_command "./scripts/jenkins/20-ci-build-and-push.sh --demo"
    echo ""

    print_info "This script will:"
    print_info "  1. Run pytest to validate code"
    print_info "  2. Build Docker image from Dockerfile"
    print_info "  3. Authenticate Docker to ECR"
    print_info "  4. Tag image with ECR URI"
    print_info "  5. Push image to this repository"
    echo ""

    print_header "Useful ECR Commands"

    print_info "View images in AWS Console:"
    print_info "  1. Open AWS Console → ECR service"
    print_info "  2. Find repository: $REPO_NAME"
    print_info "  3. Click to see all images and tags"
    echo ""

    print_info "List images via CLI:"
    print_command "aws ecr list-images --repository-name $REPO_NAME --region $AWS_REGION"
    echo ""

    print_info "Check vulnerability scan results:"
    print_command "aws ecr describe-image-scan-findings \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --image-id imageTag=latest \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_info "Delete a specific image:"
    print_command "aws ecr batch-delete-image \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --image-ids imageTag=<tag-name> \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_info "Delete the entire repository (when done):"
    print_command "aws ecr delete-repository \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --force \\"
    print_command "    --region $AWS_REGION"
    echo ""

    print_warning "Note: The --force flag deletes all images in the repository"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
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
