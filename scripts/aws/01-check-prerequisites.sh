#!/bin/bash

################################################################################
# AWS Prerequisites Check Script
################################################################################
#
# Purpose: Verify all prerequisites for AWS deployment
#
# This script checks that you have:
# - AWS CLI installed and configured
# - Valid AWS credentials (Learner Lab)
# - SAM CLI installed
# - Docker running
# - Correct AWS region configured
#
# Run this FIRST before any AWS deployment!
#
# What you'll learn:
# - How to check AWS CLI configuration
# - How to verify AWS credentials
# - How to check which AWS account you're using
# - How to validate AWS session status
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
REQUIRED_REGION="us-east-1"  # AWS Learner Lab only allows us-east-1

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

################################################################################
# Step 1: Check AWS CLI
################################################################################

check_aws_cli() {
    print_header "Step 1: Checking AWS CLI"

    print_info "The AWS CLI is a command-line tool to interact with AWS services"
    print_info "We need it to create resources, deploy applications, and manage AWS"
    echo ""

    print_info "Command to check if AWS CLI is installed:"
    print_command "aws --version"
    echo ""

    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo ""
        print_info "Install instructions:"
        print_info "  macOS: brew install awscli"
        print_info "  Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        print_info "  Windows: https://aws.amazon.com/cli/"
        echo ""
        exit 1
    fi

    AWS_VERSION=$(aws --version 2>&1)
    print_success "AWS CLI installed: ${AWS_VERSION}"

    echo ""
}

################################################################################
# Step 2: Check AWS Credentials
################################################################################

check_aws_credentials() {
    print_header "Step 2: Checking AWS Credentials"

    print_info "AWS credentials are needed to authenticate your requests"
    print_info "In Learner Lab, you get temporary credentials that expire after 4 hours"
    echo ""

    print_info "Command to check who you are authenticated as:"
    print_command "aws sts get-caller-identity"
    print_info "  - STS = Security Token Service"
    print_info "  - This returns your AWS account ID, user ARN, and user ID"
    echo ""

    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or expired"
        echo ""
        print_info "For AWS Learner Lab:"
        print_info "  1. Open Learner Lab in Canvas/AWS Academy"
        print_info "  2. Click 'Start Lab' and wait for green dot"
        print_info "  3. Click 'AWS Details'"
        print_info "  4. Click 'Show' next to AWS CLI credentials"
        print_info "  5. Copy the credentials block"
        print_info "  6. Paste into ~/.aws/credentials file"
        echo ""
        print_info "Example ~/.aws/credentials format:"
        print_info "  [default]"
        print_info "  aws_access_key_id=ASIA..."
        print_info "  aws_secret_access_key=..."
        print_info "  aws_session_token=..."
        echo ""
        exit 1
    fi

    # Get and display account info
    print_info "Retrieving AWS account information..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    USER_ID=$(aws sts get-caller-identity --query UserId --output text)

    echo ""
    print_success "AWS credentials are valid!"
    print_info "Account ID: ${ACCOUNT_ID}"
    print_info "User ARN:   ${USER_ARN}"
    print_info "User ID:    ${USER_ID}"

    echo ""
}

################################################################################
# Step 3: Check AWS Region
################################################################################

check_aws_region() {
    print_header "Step 3: Checking AWS Region"

    print_info "AWS Learner Lab restricts you to us-east-1 region only"
    print_info "All resources must be created in this region"
    echo ""

    print_info "Command to check configured region:"
    print_command "aws configure get region"
    print_info "  - This reads your default region from ~/.aws/config"
    echo ""

    CONFIGURED_REGION=$(aws configure get region || echo "not set")

    if [ "$CONFIGURED_REGION" = "not set" ] || [ -z "$CONFIGURED_REGION" ]; then
        print_warning "Region not configured"
        print_info "Setting region to us-east-1..."

        print_command "aws configure set region us-east-1"
        aws configure set region us-east-1

        print_success "Region set to us-east-1"
    elif [ "$CONFIGURED_REGION" != "$REQUIRED_REGION" ]; then
        print_error "Region is set to ${CONFIGURED_REGION}, but must be ${REQUIRED_REGION}"
        print_info "AWS Learner Lab only allows us-east-1"
        print_info "Run: aws configure set region us-east-1"
        exit 1
    else
        print_success "Region correctly set to ${REQUIRED_REGION}"
    fi

    echo ""
}

################################################################################
# Step 4: Check SAM CLI
################################################################################

check_sam_cli() {
    print_header "Step 4: Checking AWS SAM CLI"

    print_info "AWS SAM (Serverless Application Model) is a framework for building serverless apps"
    print_info "We use it to deploy Lambda functions and API Gateway"
    echo ""

    print_info "Command to check if SAM CLI is installed:"
    print_command "sam --version"
    echo ""

    if ! command -v sam &> /dev/null; then
        print_error "SAM CLI is not installed"
        echo ""
        print_info "Install instructions:"
        print_info "  macOS: brew install aws-sam-cli"
        print_info "  Linux/Windows: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
        echo ""
        exit 1
    fi

    SAM_VERSION=$(sam --version)
    print_success "SAM CLI installed: ${SAM_VERSION}"

    echo ""
}

################################################################################
# Step 5: Check Docker
################################################################################

check_docker() {
    print_header "Step 5: Checking Docker"

    print_info "Docker is needed to:"
    print_info "  1. Build container images locally"
    print_info "  2. Test images before pushing to AWS"
    print_info "  3. Push images to AWS ECR (Elastic Container Registry)"
    echo ""

    print_info "Command to check if Docker is installed:"
    print_command "docker --version"
    echo ""

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_info "Install Docker Desktop: https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed: ${DOCKER_VERSION}"

    print_info "Command to check if Docker is running:"
    print_command "docker ps"
    print_info "  - Lists running containers"
    print_info "  - If Docker daemon is not running, this fails"
    echo ""

    if ! docker ps &> /dev/null; then
        print_error "Docker is not running"
        print_info "Start Docker Desktop and try again"
        exit 1
    fi

    print_success "Docker is running"

    echo ""
}

################################################################################
# Step 6: Check Session Expiration (Learner Lab)
################################################################################

check_session_expiration() {
    print_header "Step 6: Checking Session Status (Learner Lab)"

    print_info "AWS Learner Lab sessions expire after a certain time (usually 4 hours)"
    print_info "When expired, you need to:"
    print_info "  1. Restart your lab in Canvas/AWS Academy"
    print_info "  2. Get new credentials"
    print_info "  3. Update ~/.aws/credentials"
    echo ""

    print_info "Attempting to call AWS API to check if session is active..."
    print_command "aws sts get-session-token"
    print_info "  - This command verifies your session token is still valid"
    echo ""

    # Try to get session token (this will fail if session expired)
    if aws sts get-session-token &> /dev/null 2>&1; then
        print_success "Session is active"
        print_info "Your credentials are working correctly"
    else
        print_warning "Session token check failed (this is okay for Learner Lab)"
        print_info "As long as 'aws sts get-caller-identity' works (Step 2), you're fine"
        print_info "Learner Lab uses temporary credentials that don't support get-session-token"
    fi

    echo ""
}

################################################################################
# Step 7: Display Environment Summary
################################################################################

display_summary() {
    print_header "Environment Summary"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ALL PREREQUISITES MET! ✓                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Your AWS environment:"
    echo ""

    # Account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    REGION=$(aws configure get region)

    echo -e "  ${BLUE}AWS Account ID:${NC}       ${ACCOUNT_ID}"
    echo -e "  ${BLUE}AWS Region:${NC}           ${REGION}"
    echo -e "  ${BLUE}AWS CLI Version:${NC}      $(aws --version | awk '{print $1}')"
    echo -e "  ${BLUE}SAM CLI Version:${NC}      $(sam --version | awk '{print $3}')"
    echo -e "  ${BLUE}Docker Version:${NC}       $(docker --version | awk '{print $3}' | tr -d ',')"
    echo ""

    print_header "Next Steps"

    print_info "You're ready to deploy to AWS! Here's the deployment sequence:"
    echo ""

    print_info "1. Create ECR repository (one-time setup):"
    print_command "./scripts/aws/02-setup-ecr.sh"
    print_info "   - Creates Docker registry in AWS"
    print_info "   - Stores your container images"
    echo ""

    print_info "2. Build and push Docker image:"
    print_command "./scripts/aws/03-build-and-push.sh"
    print_info "   - Builds Flask app into Docker image"
    print_info "   - Pushes to ECR for Lambda to use"
    echo ""

    print_info "3. Deploy to AWS Lambda:"
    print_command "./scripts/aws/04-deploy-sam.sh"
    print_info "   - Creates Lambda function"
    print_info "   - Sets up API Gateway"
    print_info "   - Configures CloudWatch logging"
    echo ""

    print_info "4. Verify deployment:"
    print_command "./scripts/aws/05-verify-deployment.sh"
    print_info "   - Tests API endpoints"
    print_info "   - Checks CloudWatch logs"
    echo ""

    print_info "5. Check resource status anytime:"
    print_command "./scripts/aws/check-aws-status.sh"
    print_info "   - Shows all deployed AWS resources"
    print_info "   - Displays current status and costs"
    echo ""

    print_info "6. Clean up when done:"
    print_command "./scripts/aws/99-cleanup-all.sh"
    print_info "   - Removes all AWS resources"
    print_info "   - Prevents unnecessary costs"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         AWS DEPLOYMENT PREREQUISITES CHECK                     ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Verifies your environment is ready for AWS deployment        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_aws_cli
    check_aws_credentials
    check_aws_region
    check_sam_cli
    check_docker
    check_session_expiration
    display_summary

    print_success "Prerequisites check complete!"
    echo ""
}

# Run main function
main "$@"
