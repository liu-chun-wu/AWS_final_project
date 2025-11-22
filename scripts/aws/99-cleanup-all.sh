#!/bin/bash

################################################################################
# AWS Resource Cleanup Script
################################################################################
#
# Purpose: Delete all AWS resources to avoid costs
#
# This script removes:
# - CloudFormation stack (Lambda, API Gateway, IAM roles, CloudWatch logs)
# - ECR repository and all images
# - SAM deployment bucket
#
# IMPORTANT: This is DESTRUCTIVE and IRREVERSIBLE!
#
################################################################################

set -e

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
            echo "  --demo    Delete demo-backend resources"
            echo "  --prod    Delete production resources"
            echo ""
            echo "WARNING: You MUST explicitly specify which backend to delete."
            echo "This prevents accidental production resource deletion."
            echo ""
            echo "Examples:"
            echo "  $0 --demo   # Delete demo resources (safe)"
            echo "  $0 --prod   # Delete production resources (DANGEROUS!)"
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
    echo -e "${YELLOW}You must explicitly specify which backend to DELETE:${NC}"
    echo ""
    echo "  $0 --demo   # Delete demo backend resources"
    echo "  $0 --prod   # Delete production backend resources"
    echo ""
    echo -e "${RED}This is REQUIRED to prevent accidental production deletion!${NC}"
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
    echo "  $0 --demo   # Delete demo backend"
    echo "  $0 --prod   # Delete production backend"
    exit 1
fi

REPOSITORY_NAME="aws-lab-flask-demo"
AWS_REGION="us-east-1"

# Set stack name based on flag
if [ "$USE_DEMO" = true ]; then
    STACK_NAME="flask-demo-backend"
    BACKEND_NAME="demo-backend"
elif [ "$USE_PROD" = true ]; then
    STACK_NAME="flask-prod-backend"
    BACKEND_NAME="backend"
else
    # This should never happen due to validation above
    echo "FATAL ERROR: Invalid backend state"
    exit 1
fi

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "  $1"; }

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                  AWS RESOURCE CLEANUP                          ║${NC}"
echo -e "${RED}║                                                                ║${NC}"
echo -e "${RED}║  WARNING: This will DELETE all AWS resources!                 ║${NC}"
echo -e "${RED}║  This action is IRREVERSIBLE!                                 ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Backend: ${BACKEND_NAME}${NC}"
echo -e "${YELLOW}Stack: ${STACK_NAME}${NC}"
echo ""

print_warning "Resources that will be deleted:"
print_info "  - CloudFormation stack: ${STACK_NAME}"
print_info "  - Lambda function and API Gateway"
print_info "  - IAM roles"
print_info "  - CloudWatch log groups"
print_info "  - ECR repository: ${REPOSITORY_NAME} (and all images)"
print_info "  - SAM deployment bucket"
echo ""

read -p "Are you SURE you want to delete everything? (type 'yes' to confirm): " -r
echo ""

if [ "$REPLY" != "yes" ]; then
    print_info "Cleanup cancelled"
    exit 0
fi

# Step 1: Delete CloudFormation Stack
print_header "Step 1: Deleting CloudFormation Stack"

if aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_info "Deleting stack ${STACK_NAME}..."
    print_info "Command: sam delete --stack-name ${STACK_NAME} --no-prompts --region ${AWS_REGION}"
    echo ""
    
    cd "$(dirname "$0")/../../aws"
    sam delete --stack-name ${STACK_NAME} --no-prompts --region ${AWS_REGION} || {
        print_warning "SAM delete failed, trying CloudFormation directly..."
        aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${AWS_REGION}
    }
    
    print_info "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name ${STACK_NAME} --region ${AWS_REGION} 2>/dev/null || true
    
    print_success "CloudFormation stack deleted"
else
    print_info "Stack not found (may already be deleted)"
fi

echo ""

# Step 2: Delete ECR Repository
print_header "Step 2: Deleting ECR Repository"

if aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_info "Deleting ECR repository ${REPOSITORY_NAME}..."
    print_info "Command: aws ecr delete-repository --repository-name ${REPOSITORY_NAME} --force --region ${AWS_REGION}"
    print_info "  --force deletes repository even if it contains images"
    echo ""
    
    aws ecr delete-repository \
        --repository-name ${REPOSITORY_NAME} \
        --force \
        --region ${AWS_REGION}
    
    print_success "ECR repository deleted"
else
    print_info "ECR repository not found (may already be deleted)"
fi

echo ""

# Step 3: Delete SAM Deployment Bucket (Optional)
print_header "Step 3: Deleting SAM Deployment Bucket"

print_info "Finding SAM deployment bucket..."
SAM_BUCKET=$(aws s3 ls | grep "aws-sam-cli-managed-default" | awk '{print $3}' | head -1)

if [ -n "$SAM_BUCKET" ]; then
    print_info "Found SAM bucket: ${SAM_BUCKET}"
    print_info "Command: aws s3 rb s3://${SAM_BUCKET} --force"
    print_info "  --force deletes bucket even if it contains objects"
    echo ""
    
    aws s3 rb "s3://${SAM_BUCKET}" --force
    print_success "SAM deployment bucket deleted"
else
    print_info "No SAM deployment bucket found"
fi

echo ""

# Step 4: Verify Cleanup
print_header "Step 4: Verifying Cleanup"

RESOURCES_REMAINING=0

# Check stack
if aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_warning "CloudFormation stack still exists"
    RESOURCES_REMAINING=$((RESOURCES_REMAINING + 1))
else
    print_success "CloudFormation stack: Deleted"
fi

# Check ECR
if aws ecr describe-repositories --repository-names ${REPOSITORY_NAME} --region ${AWS_REGION} &>/dev/null; then
    print_warning "ECR repository still exists"
    RESOURCES_REMAINING=$((RESOURCES_REMAINING + 1))
else
    print_success "ECR repository: Deleted"
fi

echo ""

if [ $RESOURCES_REMAINING -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          CLEANUP COMPLETE! ✓                                   ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_success "All AWS resources have been deleted"
    print_info "Your Learner Lab budget has been freed up"
else
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║          CLEANUP INCOMPLETE                                    ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_warning "${RESOURCES_REMAINING} resource(s) may still exist"
    print_info "Check AWS Console or run: ./scripts/aws/check-aws-status.sh"
fi

echo ""
