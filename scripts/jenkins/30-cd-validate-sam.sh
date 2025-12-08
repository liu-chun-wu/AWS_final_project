#!/bin/bash

################################################################################
# SAM Template Validation Script
################################################################################
#
# Script: 30-cd-validate-sam.sh
# Purpose: Validate SAM template and check deployment prerequisites
# Usage: ./30-cd-validate-sam.sh
#
# What is SAM (Serverless Application Model)?
# - AWS framework for building serverless applications
# - Simplifies CloudFormation templates for Lambda, API Gateway, DynamoDB
# - Transforms short SAM syntax into full CloudFormation
# - Provides local testing capabilities
# - Open-source tool from AWS (GitHub: aws/serverless-application-model)
#
# What is CloudFormation?
# - AWS's Infrastructure as Code (IaC) service
# - Define AWS resources in YAML/JSON templates
# - Creates/updates/deletes resources as a "stack"
# - Provides rollback on failures
# - Manages resource dependencies automatically
#
# This script validates:
# 1. SAM template syntax (YAML structure, required fields)
# 2. ECR repository exists (for Lambda container image)
# 3. Docker images exist in ECR (for deployment)
# 4. LabRole exists (AWS Learner Lab IAM role)
# 5. SAM can build successfully
#
# What you'll learn:
# - SAM template structure and validation
# - CloudFormation basics
# - IAM roles for Lambda (LabRole in Learner Lab)
# - Prerequisites validation pattern
# - "Validate early, fail fast" principle
#
# AWS Services Used:
# - SAM CLI - Template validation and building
# - CloudFormation - Infrastructure deployment (via SAM)
# - ECR - Container image storage
# - IAM - Role validation (LabRole)
#
# Prerequisites:
# - SAM CLI installed (sam --version)
# - AWS CLI configured with valid credentials
# - ECR repository created (11-setup-ecr.sh)
# - Docker image pushed to ECR (20-ci-build-and-push.sh)
#
# Cost:
# - Validation is FREE (no AWS resources created)
# - SAM build runs locally (no cost)
#
################################################################################

set -e  # Exit immediately if any command fails

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="aws-lab-flask-demo"

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
    echo -e "${BLUE}║       PHASE 3b: SAM TEMPLATE VALIDATION                        ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║  Validate deployment prerequisites before CD                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_header "What is AWS SAM?"

    print_info "AWS Serverless Application Model (SAM) is a framework for serverless apps:"
    print_info "  • Simplified CloudFormation syntax for Lambda + API Gateway + DynamoDB"
    print_info "  • Transforms SAM template → full CloudFormation template"
    print_info "  • Provides 'sam local' for testing Lambda functions locally"
    print_info "  • Manages deployment packaging and uploads"
    print_info "  • Open-source and actively maintained by AWS"
    echo ""

    print_info "SAM vs CloudFormation:"
    print_info "  • SAM: High-level, serverless-focused (fewer lines of code)"
    print_info "  • CloudFormation: Low-level, supports all AWS resources"
    print_info "  • SAM templates are CloudFormation templates with extra syntax"
    print_info "  • 'sam deploy' translates SAM → CloudFormation → AWS resources"
    echo ""

    print_header "What is CloudFormation?"

    print_info "CloudFormation is AWS's Infrastructure as Code (IaC) service:"
    print_info "  • Define infrastructure in YAML/JSON templates"
    print_info "  • Deploy resources as a 'stack' (group of related resources)"
    print_info "  • Update stacks safely (change sets preview changes)"
    print_info "  • Rollback on failures (automatic cleanup)"
    print_info "  • Track dependencies (creates resources in correct order)"
    echo ""

    print_info "Example CloudFormation stack for this project:"
    print_info "  • Lambda function (from ECR container image)"
    print_info "  • API Gateway (HTTP endpoints)"
    print_info "  • IAM execution role (LabRole for permissions)"
    print_info "  • CloudWatch Logs (for Lambda output)"
    echo ""

    print_info "Configuration:"
    echo -e "  ${BLUE}AWS Region:${NC}        $AWS_REGION"
    echo -e "  ${BLUE}ECR Repository:${NC}    $REPO_NAME"
    echo -e "  ${BLUE}Template Path:${NC}     aws/template.yaml"
    echo ""
}

################################################################################
# Step 1: Validate SAM Template Syntax
################################################################################

validate_template() {
    print_header "Step 1: Validating SAM Template Syntax"

    cd "$PROJECT_ROOT"

    print_info "SAM templates must follow specific structure and syntax"
    echo ""

    print_info "Validation command:"
    print_command "sam validate --template aws/template.yaml"
    echo ""

    print_explain "What 'sam validate' checks:"
    print_explain "  • Valid YAML syntax (indentation, structure)"
    print_explain "  • Required SAM/CloudFormation fields present"
    print_explain "  • Resource types are valid (AWS::Serverless::Function, etc.)"
    print_explain "  • Property names spelled correctly"
    print_explain "  • Intrinsic functions used properly (!Ref, !GetAtt, etc.)"
    echo ""

    print_info "What validation does NOT check:"
    print_info "  ✗ Whether resources actually exist (ECR image, IAM roles)"
    print_info "  ✗ Whether you have permissions to create resources"
    print_info "  ✗ Whether deployment will succeed"
    print_info "  → These are checked in later steps"
    echo ""

    if [ ! -f "aws/template.yaml" ]; then
        print_error "SAM template not found at aws/template.yaml"
        echo ""
        print_info "Expected structure:"
        print_info "  $PROJECT_ROOT/aws/template.yaml"
        echo ""
        print_info "The template should define:"
        print_info "  • Lambda function using container image from ECR"
        print_info "  • API Gateway for HTTP endpoints"
        print_info "  • IAM role (LabRole) for Lambda execution"
        exit 1
    fi

    print_info "Validating template..."
    echo ""

    if sam validate --template aws/template.yaml; then
        echo ""
        print_success "SAM template syntax is valid ✓"
        print_info "Template structure and CloudFormation syntax are correct"
    else
        echo ""
        print_error "SAM template validation failed"
        echo ""
        print_info "Common template issues:"
        print_info "  • YAML indentation errors (use spaces, not tabs)"
        print_info "  • Missing required fields (Handler, Runtime, CodeUri)"
        print_info "  • Typos in resource type names"
        print_info "  • Invalid intrinsic function syntax"
        echo ""
        print_info "Review error message above and fix template"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 2: Check ECR Repository Exists
################################################################################

check_ecr_repository() {
    print_header "Step 2: Checking ECR Repository"

    print_info "Lambda container functions require images in ECR"
    echo ""

    print_info "Query command:"
    print_command "aws ecr describe-repositories \\"
    print_command "    --repository-names $REPO_NAME \\"
    print_command "    --region $AWS_REGION"
    echo ""

    ECR_REPO_URI=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null)

    if [ -z "$ECR_REPO_URI" ]; then
        print_error "ECR repository not found"
        echo ""
        print_info "ECR repository must be created first"
        print_info "Run: ./scripts/jenkins/11-setup-ecr.sh"
        echo ""
        exit 1
    fi

    print_success "ECR repository exists: $ECR_REPO_URI"
    echo ""
}

################################################################################
# Step 3: Check Images in ECR
################################################################################

check_ecr_images() {
    print_header "Step 3: Checking for Images in ECR"

    print_info "Deployment requires at least one Docker image in ECR"
    echo ""

    print_info "List images command:"
    print_command "aws ecr list-images \\"
    print_command "    --repository-name $REPO_NAME \\"
    print_command "    --region $AWS_REGION"
    echo ""

    IMAGE_COUNT=$(aws ecr list-images \
        --repository-name "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query 'length(imageIds)' \
        --output text 2>/dev/null)

    if [ "$IMAGE_COUNT" -gt 0 ]; then
        print_success "Found $IMAGE_COUNT image(s) in ECR"
        echo ""

        print_info "Available images (last 5):"
        aws ecr describe-images \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --query 'sort_by(imageDetails,&imagePushedAt)[-5:].{Tag:imageTags[0],Pushed:imagePushedAt,Size:imageSizeInBytes}' \
            --output table

        echo ""

        print_explain "Deployment notes:"
        print_explain "  • Lambda will pull image from ECR at deploy time"
        print_explain "  • Image must be in same region as Lambda (us-east-1)"
        print_explain "  • Can deploy with specific tag or 'latest'"
    else
        print_warning "No images in ECR yet"
        echo ""
        print_info "You need to build and push an image first"
        print_info "Run: ./scripts/jenkins/20-ci-build-and-push.sh --demo"
        echo ""
        print_info "This validation can continue, but deployment will fail without images"
    fi

    echo ""
}

################################################################################
# Step 4: Check LabRole Exists
################################################################################

check_lab_role() {
    print_header "Step 4: Checking for LabRole (AWS Learner Lab)"

    print_info "What is LabRole?"
    print_info "  • Pre-created IAM role in AWS Learner Lab"
    print_info "  • Provides permissions for Lambda, ECR, CloudWatch, etc."
    print_info "  • Cannot create custom IAM roles in Learner Lab (restricted)"
    print_info "  • Must use LabRole for Lambda execution"
    echo ""

    print_info "What is an IAM Role?"
    print_info "  • AWS identity with permissions (policies)"
    print_info "  • Services assume roles (Lambda assumes LabRole)"
    print_info "  • Grants temporary credentials to service"
    print_info "  • More secure than embedding access keys"
    echo ""

    print_info "Checking for LabRole..."
    print_command "aws iam get-role --role-name LabRole"
    echo ""

    ROLE_ARN=$(aws iam get-role \
        --role-name LabRole \
        --query 'Role.Arn' \
        --output text 2>/dev/null)

    if [ -n "$ROLE_ARN" ]; then
        print_success "LabRole exists: $ROLE_ARN"
        echo ""

        print_explain "Understanding the ARN:"
        echo -e "    ${CYAN}$ROLE_ARN${NC}"
        print_explain "    Format: arn:aws:iam::<account-id>:role/LabRole"
        print_explain "    • ARN = Amazon Resource Name (unique identifier)"
        print_explain "    • Used in SAM template to reference this role"
        echo ""

        print_info "LabRole permissions (typical):"
        print_info "  • ECR: Pull container images"
        print_info "  • CloudWatch Logs: Write logs"
        print_info "  • Lambda: Execute function code"
        print_info "  • Various read permissions for AWS services"
    else
        print_error "LabRole not found"
        echo ""
        print_info "LabRole is required for AWS Learner Lab deployments"
        echo ""
        print_info "Common issues:"
        print_info "  • Not using AWS Learner Lab (LabRole doesn't exist)"
        print_info "  • Learner Lab session expired (restart lab)"
        print_info "  • Wrong AWS account/credentials"
        echo ""
        print_info "For AWS Learner Lab:"
        print_info "  1. Ensure lab is started (green indicator)"
        print_info "  2. LabRole should exist automatically"
        print_info "  3. Your SAM template must reference LabRole, not create new roles"
        exit 1
    fi

    echo ""
}

################################################################################
# Step 5: Test SAM Build
################################################################################

test_sam_build() {
    print_header "Step 5: Testing SAM Build"

    print_info "SAM build prepares deployment package"
    echo ""

    print_info "Build command:"
    print_command "sam build --use-container --template aws/template.yaml"
    echo ""

    print_explain "Parameters explained:"
    print_explain "  • --use-container:"
    print_explain "    → Builds Lambda code inside Docker container"
    print_explain "    → Ensures consistent build environment"
    print_explain "    → Matches Lambda runtime environment"
    print_explain "    → For container images, validates Dockerfile"
    print_explain ""
    print_explain "  • --template aws/template.yaml:"
    print_explain "    → Specifies SAM template location"
    print_explain "    → Default is template.yaml in current directory"
    echo ""

    print_info "What happens during 'sam build':"
    print_info "  1. Reads SAM template"
    print_info "  2. For container image functions:"
    print_info "     • Validates image reference exists in ECR"
    print_info "     • No local build needed (image already in ECR)"
    print_info "  3. For ZIP functions (not used in this project):"
    print_info "     • Installs dependencies"
    print_info "     • Packages code"
    print_info "  4. Creates .aws-sam/ build directory"
    print_info "  5. Generates CloudFormation template"
    echo ""

    print_info "Building (this may take 30-60 seconds)..."
    echo ""

    if sam build --use-container --template aws/template.yaml; then
        echo ""
        print_success "SAM build successful ✓"
        echo ""

        print_info "Build artifacts created:"
        print_info "  • .aws-sam/build/ directory"
        print_info "  • CloudFormation template (transformed from SAM)"
        echo ""

        print_explain "Build validation confirmed:"
        print_explain "  • Template structure is correct"
        print_explain "  • All required resources defined"
        print_explain "  • Ready for deployment"
    else
        echo ""
        print_error "SAM build failed"
        echo ""
        print_info "Common build issues:"
        print_info "  • Template references non-existent ECR image"
        print_info "  • Docker daemon not running (for --use-container)"
        print_info "  • Invalid PackageType or ImageUri in template"
        print_info "  • Missing required template properties"
        echo ""
        print_info "Review error output above for specific issue"
        exit 1
    fi

    echo ""
}

################################################################################
# Display Summary
################################################################################

display_summary() {
    print_header "SAM Validation Complete ✅"

    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ALL PREREQUISITES VALIDATED! ✓                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Validation results:"
    print_info "  ✓ SAM template syntax valid"
    print_info "  ✓ ECR repository exists"
    if [ "$IMAGE_COUNT" -gt 0 ]; then
        print_info "  ✓ Docker images available in ECR ($IMAGE_COUNT)"
    else
        print_info "  ⚠ No images in ECR (need to run 20-ci-build-and-push.sh)"
    fi
    print_info "  ✓ LabRole exists (IAM execution role)"
    print_info "  ✓ SAM build succeeds"
    echo ""

    echo -e "  ${BLUE}Template:${NC}      aws/template.yaml"
    echo -e "  ${BLUE}ECR URI:${NC}       $ECR_REPO_URI"
    echo -e "  ${BLUE}IAM Role:${NC}      $ROLE_ARN"
    echo -e "  ${BLUE}Region:${NC}        $AWS_REGION"
    echo ""

    print_header "Phase 3b: Deploy SAM (Next)"

    print_info "Ready to deploy to AWS Lambda + API Gateway:"
    print_command "./scripts/jenkins/31-cd-deploy-sam.sh --demo"
    print_info "  OR"
    print_command "./scripts/jenkins/31-cd-deploy-sam.sh --prod"
    echo ""

    print_info "What deployment will do:"
    print_info "  1. Package SAM template"
    print_info "  2. Create CloudFormation change set"
    print_info "  3. Deploy Lambda function from ECR image"
    print_info "  4. Create API Gateway endpoints"
    print_info "  5. Configure CloudWatch Logs"
    print_info "  6. Return API Gateway URL for testing"
    echo ""

    print_header "Understanding SAM Deployment"

    print_info "SAM → CloudFormation → AWS Resources:"
    print_info ""
    print_info "  1. SAM template (aws/template.yaml)"
    print_info "     ↓"
    print_info "  2. sam deploy transforms to CloudFormation"
    print_info "     ↓"
    print_info "  3. CloudFormation creates change set (preview)"
    print_info "     ↓"
    print_info "  4. CloudFormation executes change set"
    print_info "     ↓"
    print_info "  5. AWS resources created in order:"
    print_info "       • IAM role association (LabRole)"
    print_info "       • Lambda function (pulls ECR image)"
    print_info "       • API Gateway (creates HTTP endpoints)"
    print_info "       • CloudWatch Logs (log groups)"
    print_info "     ↓"
    print_info "  6. Stack status: CREATE_COMPLETE"
    echo ""

    print_info "Useful commands:"
    echo ""

    print_info "View template in detail:"
    print_command "cat aws/template.yaml"
    echo ""

    print_info "View generated CloudFormation template:"
    print_command "cat .aws-sam/build/template.yaml"
    echo ""

    print_info "Validate template changes:"
    print_command "sam validate --template aws/template.yaml --lint"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    show_introduction
    validate_template
    check_ecr_repository
    check_ecr_images
    check_lab_role
    test_sam_build
    display_summary

    print_success "Validation complete - ready for deployment!"
    echo ""
}

# Run main function
main "$@"
